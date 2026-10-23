-- B8: fixed-window rate limits for paid/abusive Edge Functions.
-- Only the Edge Functions (service role) can consume; clients cannot call this
-- with an arbitrary subject.

create table if not exists public.rate_limits (
  subject uuid not null,
  action text not null,
  window_start timestamptz not null,
  count integer not null default 0,
  primary key (subject, action, window_start)
);

create index if not exists rate_limits_window_idx
  on public.rate_limits (window_start);

alter table public.rate_limits enable row level security;
revoke all on public.rate_limits from anon;
revoke all on public.rate_limits from authenticated;

create or replace function public.consume_rate_limit(
  p_subject uuid,
  p_action text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window timestamptz;
  v_count integer;
begin
  if p_subject is null or btrim(coalesce(p_action, '')) = ''
     or p_limit <= 0 or p_window_seconds <= 0 then
    return false;
  end if;

  v_window := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );

  insert into public.rate_limits (subject, action, window_start, count)
  values (p_subject, p_action, v_window, 1)
  on conflict (subject, action, window_start)
  do update set count = public.rate_limits.count + 1
  returning count into v_count;

  return v_count <= p_limit;
end;
$$;

revoke all on function public.consume_rate_limit(uuid, text, integer, integer) from public;
revoke all on function public.consume_rate_limit(uuid, text, integer, integer) from anon;
revoke all on function public.consume_rate_limit(uuid, text, integer, integer) from authenticated;
grant execute on function public.consume_rate_limit(uuid, text, integer, integer) to service_role;

-- Keep the table small.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'rate-limit-cleanup') then
    perform cron.unschedule('rate-limit-cleanup');
  end if;
end $$;

select cron.schedule(
  'rate-limit-cleanup',
  '15 * * * *',
  $cron$
    delete from public.rate_limits
    where window_start < now() - interval '1 day';
  $cron$
);
