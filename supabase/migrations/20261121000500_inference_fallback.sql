-- Rerank fallback + inference telemetry.
--
-- Priority is the configured primary rerank provider (for example NVIDIA NIM).
-- If it is unresponsive, get-matches retries the same call on the fallback
-- provider (DeepInfra) and records the outcome. A circuit breaker in
-- provider_circuit stops hammering a failing primary for a cool-down window,
-- shared across every Edge Function instance.

-- Cached decks remember which provider produced the rerank so cached responses
-- can report fallback usage accurately.
alter table public.match_cache add column if not exists rerank_provider text;

create table if not exists public.inference_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  surface text not null default 'get_matches',
  operation text not null default 'rerank',
  primary_provider text not null,
  fallback_provider text,
  used_provider text not null,
  primary_calls integer not null default 0,
  primary_failures integer not null default 0,
  fallback_calls integer not null default 0,
  fallback_failures integer not null default 0,
  primary_latency_ms integer not null default 0,
  fallback_latency_ms integer not null default 0,
  primary_samples_ms integer[] not null default '{}',
  fallback_samples_ms integer[] not null default '{}',
  latency_ms integer,
  mode text,
  error text
);

alter table public.inference_events
  add column if not exists primary_samples_ms integer[] not null default '{}';
alter table public.inference_events
  add column if not exists fallback_samples_ms integer[] not null default '{}';

create index if not exists inference_events_created_at_idx
  on public.inference_events (created_at desc);
create index if not exists inference_events_provider_idx
  on public.inference_events (primary_provider, operation, created_at desc);

create table if not exists public.provider_circuit (
  provider text not null,
  operation text not null,
  status text not null default 'healthy',
  consecutive_failures integer not null default 0,
  breaker_until timestamptz,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  last_error text,
  updated_at timestamptz not null default now(),
  primary key (provider, operation)
);

alter table public.inference_events enable row level security;
alter table public.provider_circuit enable row level security;

revoke all on table public.inference_events from public, anon, authenticated;
revoke all on table public.provider_circuit from public, anon, authenticated;
grant select, insert on table public.inference_events to service_role;
grant select, insert, update on table public.provider_circuit to service_role;

-- One call per deck. `p_success` resets the breaker; `p_failure` increments it.
create or replace function public.record_rerank_circuit(
  p_provider text,
  p_success boolean,
  p_failure boolean,
  p_error text,
  p_threshold integer,
  p_cooldown_seconds integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_threshold integer := greatest(1, coalesce(p_threshold, 3));
  v_cooldown integer := greatest(10, coalesce(p_cooldown_seconds, 60));
begin
  if not coalesce(p_success, false) and not coalesce(p_failure, false) then
    return;
  end if;

  insert into public.provider_circuit (
    provider, operation, status, consecutive_failures,
    breaker_until, last_success_at, last_failure_at, last_error, updated_at
  )
  values (
    p_provider,
    'rerank',
    case when p_failure and v_threshold <= 1 then 'open'
         when p_failure then 'degraded' else 'healthy' end,
    case when p_failure then 1 else 0 end,
    case when p_failure and v_threshold <= 1
      then now() + make_interval(secs => v_cooldown) else null end,
    case when p_success then now() else null end,
    case when p_failure then now() else null end,
    case when p_failure then left(coalesce(p_error, ''), 300) else null end,
    now()
  )
  on conflict (provider, operation) do update
  set consecutive_failures = case
        when p_failure then public.provider_circuit.consecutive_failures + 1
        when p_success then 0
        else public.provider_circuit.consecutive_failures
      end,
      status = case
        when p_success then 'healthy'
        when p_failure and public.provider_circuit.consecutive_failures + 1 >= v_threshold then 'open'
        when p_failure then 'degraded'
        else public.provider_circuit.status
      end,
      breaker_until = case
        when p_success then null
        when p_failure and public.provider_circuit.consecutive_failures + 1 >= v_threshold
          then now() + make_interval(secs => v_cooldown)
        else public.provider_circuit.breaker_until
      end,
      last_success_at = case when p_success then now() else public.provider_circuit.last_success_at end,
      last_failure_at = case when p_failure then now() else public.provider_circuit.last_failure_at end,
      last_error = case when p_failure then left(coalesce(p_error, ''), 300) else null end,
      updated_at = now();
end;
$$;

revoke all on function public.record_rerank_circuit(text, boolean, boolean, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.record_rerank_circuit(text, boolean, boolean, text, integer, integer)
  to service_role;

-- Read-only rollup for Admin -> Analytics -> System.
create or replace function public.admin_inference_system()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with days as (
  select generate_series(current_date - 13, current_date, interval '1 day')::date as day
),
recent as (
  select * from public.inference_events
  where created_at >= now() - interval '14 days'
),
win as (
  select * from public.inference_events
  where created_at >= now() - interval '7 days'
),
call_samples as (
  select provider, operation, latency_ms, created_at
  from (
    select
      primary_provider as provider,
      operation,
      unnest(
        case
          when cardinality(primary_samples_ms) > 0 then primary_samples_ms
          when primary_calls > 0
            then array[(primary_latency_ms / primary_calls)::int]
          else '{}'::int[]
        end
      ) as latency_ms,
      created_at
    from win
    union all
    select
      fallback_provider as provider,
      operation,
      unnest(
        case
          when cardinality(fallback_samples_ms) > 0 then fallback_samples_ms
          when fallback_calls > 0
            then array[(fallback_latency_ms / fallback_calls)::int]
          else '{}'::int[]
        end
      ) as latency_ms,
      created_at
    from win
    where fallback_provider is not null
  ) q
),
call_stats as (
  select
    provider,
    operation,
    count(*)::int as samples,
    avg(latency_ms) as avg_ms,
    percentile_cont(0.5) within group (order by latency_ms) as p50_ms,
    percentile_cont(0.95) within group (order by latency_ms) as p95_ms
  from call_samples
  group by provider, operation
),
failure_stats as (
  select
    provider,
    operation,
    sum(calls)::int as attempts,
    sum(failures)::int as failures,
    max(created_at) filter (where calls > 0 and failures = 0) as event_last_success_at,
    max(created_at) filter (where failures > 0) as event_last_failure_at
  from (
    select
      primary_provider as provider,
      operation,
      primary_calls as calls,
      primary_failures as failures,
      created_at
    from win
    union all
    select
      fallback_provider as provider,
      operation,
      fallback_calls as calls,
      fallback_failures as failures,
      created_at
    from win
    where fallback_provider is not null
  ) q
  group by provider, operation
),
provider_rows as (
  select
    f.provider,
    f.operation,
    f.attempts,
    f.failures,
    case when f.attempts > 0
      then round((f.attempts - f.failures)::numeric / f.attempts, 4)
      else null end as success_rate,
    round(c.avg_ms) as avg_ms,
    round(c.p50_ms) as p50_ms,
    round(c.p95_ms) as p95_ms,
    case
      when coalesce(pc.status, 'healthy') = 'open'
        and (pc.breaker_until is null or pc.breaker_until <= now())
        then 'degraded'
      else coalesce(
        pc.status,
        case when f.attempts > 0 and f.failures::numeric / f.attempts >= 0.5
          then 'degraded' else 'healthy' end
      )
    end as status,
    pc.consecutive_failures,
    case when pc.breaker_until > now() then pc.breaker_until else null end as breaker_until,
    coalesce(pc.last_success_at, f.event_last_success_at) as last_success_at,
    coalesce(pc.last_failure_at, f.event_last_failure_at) as last_failure_at,
    pc.last_error
  from failure_stats f
  left join call_stats c
    on c.provider = f.provider and c.operation = f.operation
  left join public.provider_circuit pc
    on pc.provider = f.provider and pc.operation = f.operation
),
daily as (
  select
    d.day,
    count(e.id) filter (
      where (e.primary_calls + e.fallback_calls) > 0
        and e.used_provider = e.primary_provider
    )::int as primary_events,
    count(e.id) filter (
      where (e.primary_calls + e.fallback_calls) > 0
        and e.used_provider = e.fallback_provider
    )::int as fallback_events,
    count(e.id) filter (
      where (e.primary_calls + e.fallback_calls) > 0
        and e.used_provider = 'mixed'
    )::int as mixed_events,
    count(e.id) filter (where e.mode = 'basic_bi')::int as failed_events
  from days d
  left join recent e
    on e.created_at >= d.day
   and e.created_at < d.day + 1
  group by d.day
)
select jsonb_build_object(
  'config', jsonb_build_object(
    'embed_provider', coalesce(
      (select value #>> '{}' from public.pipeline_config where key = 'embed_provider'),
      (select value #>> '{}' from public.pipeline_config where key = 'inference_provider')
    ),
    'rerank_provider', coalesce(
      (select value #>> '{}' from public.pipeline_config where key = 'rerank_provider'),
      (select value #>> '{}' from public.pipeline_config where key = 'inference_provider')
    ),
    'rerank_fallback_provider', (select value #>> '{}' from public.pipeline_config where key = 'rerank_fallback_provider'),
    'rerank_failure_threshold', (select value #>> '{}' from public.pipeline_config where key = 'rerank_failure_threshold'),
    'rerank_cooldown_seconds', (select value #>> '{}' from public.pipeline_config where key = 'rerank_cooldown_seconds')
  ),
  'usage', jsonb_build_object(
    'decks_7d', (select count(*)::int from win),
    'rerank_calls_7d', (
      select coalesce(sum(primary_calls + fallback_calls), 0)::int from win
    ),
    'fallback_events_7d', (
      select count(*)::int from win
      where (primary_calls + fallback_calls) > 0
        and (fallback_calls - fallback_failures) > 0
    ),
    'failed_events_7d', (
      select count(*)::int from win where mode = 'basic_bi'
    ),
    'last_event_at', (select max(created_at) from public.inference_events)
  ),
  'fallback_rate', (
    select case
      when count(*) filter (where primary_calls + fallback_calls > 0) > 0
      then round(
        count(*) filter (
          where primary_calls + fallback_calls > 0
            and fallback_calls - fallback_failures > 0
        )::numeric
        / count(*) filter (where primary_calls + fallback_calls > 0),
        4
      )
      else null
    end
    from win
  ),
  'providers', coalesce((
    select jsonb_agg(jsonb_build_object(
      'provider', provider,
      'operation', operation,
      'attempts', attempts,
      'failures', failures,
      'success_rate', success_rate,
      'avg_ms', avg_ms,
      'p50_ms', p50_ms,
      'p95_ms', p95_ms,
      'status', coalesce(status, 'healthy'),
      'consecutive_failures', coalesce(consecutive_failures, 0),
      'breaker_until', breaker_until,
      'last_success_at', last_success_at,
      'last_failure_at', last_failure_at,
      'last_error', last_error
    ) order by provider, operation)
    from provider_rows
  ), '[]'::jsonb),
  'daily', coalesce((
    select jsonb_agg(jsonb_build_object(
      'day', day,
      'primary', primary_events,
      'fallback', fallback_events,
      'mixed', mixed_events,
      'failed', failed_events
    ) order by day)
    from daily
  ), '[]'::jsonb),
  'recent', coalesce((
    select jsonb_agg(jsonb_build_object(
      'created_at', created_at,
      'primary_provider', primary_provider,
      'fallback_provider', fallback_provider,
      'used_provider', used_provider,
      'primary_calls', primary_calls,
      'primary_failures', primary_failures,
      'fallback_calls', fallback_calls,
      'fallback_failures', fallback_failures,
      'latency_ms', latency_ms,
      'mode', mode,
      'error', error
    ) order by created_at desc)
    from (
      select * from public.inference_events
      order by created_at desc
      limit 10
    ) q
  ), '[]'::jsonb)
);
$$;

revoke all on function public.admin_inference_system() from public, anon, authenticated;
grant execute on function public.admin_inference_system() to service_role;

-- Fallback routing knobs. The live priority is set by the admin publish path.
insert into public.pipeline_config (key, value, description)
values
  (
    'rerank_fallback_provider',
    to_jsonb('deepinfra'::text),
    'Fallback rerank provider when the primary is unresponsive: deepinfra, nvidia, or none.'
  ),
  (
    'rerank_failure_threshold',
    to_jsonb(3),
    'Consecutive primary rerank failures before the circuit breaker opens.'
  ),
  (
    'rerank_cooldown_seconds',
    to_jsonb(60),
    'How long the circuit breaker skips a failing primary rerank provider.'
  )
on conflict (key) do nothing;

-- Keep the telemetry table bounded. Guarded so environments without pg_cron
-- can still apply the migration; cron.sql schedules the same job explicitly.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (
      select 1 from cron.job where jobname = 'inference-events-cleanup'
    ) then
      perform cron.unschedule('inference-events-cleanup');
    end if;
    perform cron.schedule(
      'inference-events-cleanup',
      '25 * * * *',
      $cron$delete from public.inference_events where created_at < now() - interval '30 days';$cron$
    );
  end if;
exception when others then null;
end $$;
