-- Admin panel foundation: allowlisted admins, audit, saved views, config
-- versions, skill change history, sandbox runs, and analytics RPCs.
--
-- The admin frontend never reads these tables directly. It calls the
-- `admin-api` Edge Function, which uses the service role after checking the
-- caller's admin row, role, and MFA level.

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'analyst'
    check (role in ('owner', 'admin', 'analyst', 'moderator', 'support')),
  status text not null default 'active'
    check (status in ('active', 'disabled')),
  mfa_required boolean not null default true,
  created_by uuid,
  created_at timestamp with time zone not null default now(),
  last_login_at timestamp with time zone
);

create table if not exists public.admin_audit_log (
  id bigserial primary key,
  actor_id uuid,
  actor_email text,
  action text not null,
  target_type text,
  target_id text,
  detail jsonb,
  reason text,
  ip text,
  user_agent text,
  created_at timestamp with time zone not null default now()
);
create index if not exists admin_audit_created_idx
  on public.admin_audit_log (created_at desc);
create index if not exists admin_audit_actor_idx
  on public.admin_audit_log (actor_id, created_at desc);

create table if not exists public.admin_saved_views (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  surface text not null,
  name text not null,
  config jsonb not null default '{}'::jsonb,
  shared boolean not null default false,
  created_at timestamp with time zone not null default now()
);
create index if not exists admin_saved_views_owner_idx
  on public.admin_saved_views (owner_id, surface);

create table if not exists public.admin_exports (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  surface text not null,
  format text not null check (format in ('csv', 'json')),
  row_count integer not null default 0,
  storage_path text,
  expires_at timestamp with time zone,
  created_at timestamp with time zone not null default now()
);
create index if not exists admin_exports_created_idx
  on public.admin_exports (created_at desc);

create table if not exists public.pipeline_config_versions (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  config jsonb not null,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'archived')),
  created_by uuid,
  created_at timestamp with time zone not null default now(),
  published_by uuid,
  published_at timestamp with time zone,
  notes text
);
create index if not exists pipeline_config_versions_created_idx
  on public.pipeline_config_versions (created_at desc);

create table if not exists public.skill_change_log (
  id bigserial primary key,
  node_id uuid,
  action text not null,
  before jsonb,
  after jsonb,
  reason text,
  actor_id uuid,
  created_at timestamp with time zone not null default now()
);
create index if not exists skill_change_log_node_idx
  on public.skill_change_log (node_id, created_at desc);

create table if not exists public.sandbox_runs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  sample_size integer not null default 100,
  baseline_revision integer,
  candidate_config jsonb not null,
  summary jsonb,
  status text not null default 'running'
    check (status in ('running', 'complete', 'failed')),
  error text,
  started_at timestamp with time zone not null default now(),
  finished_at timestamp with time zone
);
create index if not exists sandbox_runs_created_idx
  on public.sandbox_runs (started_at desc);

create table if not exists public.sandbox_results (
  id bigserial primary key,
  run_id uuid not null references public.sandbox_runs(id) on delete cascade,
  user_id uuid,
  as_role text,
  candidate_id uuid,
  baseline_rank integer,
  candidate_rank integer,
  baseline_score real,
  candidate_score real,
  delta real
);
create index if not exists sandbox_results_run_idx
  on public.sandbox_results (run_id, baseline_rank);

create table if not exists public.analytics_events (
  id bigserial primary key,
  event_name text not null,
  user_id uuid,
  session_id text,
  properties jsonb not null default '{}'::jsonb,
  platform text,
  app_version text,
  occurred_at timestamp with time zone not null default now()
);
create index if not exists analytics_events_name_time_idx
  on public.analytics_events (event_name, occurred_at desc);
create index if not exists analytics_events_user_time_idx
  on public.analytics_events (user_id, occurred_at desc);

-- Case-handling fields on reports.
alter table public.reports
  add column if not exists assigned_to uuid references public.profiles(id) on delete set null,
  add column if not exists resolution text,
  add column if not exists resolved_at timestamp with time zone;
create index if not exists reports_assigned_idx
  on public.reports (assigned_to, status);

-- Service-role-only access. The admin API is the only reader/writer.
alter table public.admin_users enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.admin_saved_views enable row level security;
alter table public.admin_exports enable row level security;
alter table public.pipeline_config_versions enable row level security;
alter table public.skill_change_log enable row level security;
alter table public.sandbox_runs enable row level security;
alter table public.sandbox_results enable row level security;
alter table public.analytics_events enable row level security;

revoke all on public.admin_users from anon, authenticated;
revoke all on public.admin_audit_log from anon, authenticated;
revoke all on public.admin_saved_views from anon, authenticated;
revoke all on public.admin_exports from anon, authenticated;
revoke all on public.pipeline_config_versions from anon, authenticated;
revoke all on public.skill_change_log from anon, authenticated;
revoke all on public.sandbox_runs from anon, authenticated;
revoke all on public.sandbox_results from anon, authenticated;
revoke all on public.analytics_events from anon, authenticated;

grant all on public.admin_users to service_role;
grant select, insert on public.admin_audit_log to service_role;
grant all on public.admin_saved_views to service_role;
grant all on public.admin_exports to service_role;
grant all on public.pipeline_config_versions to service_role;
grant all on public.skill_change_log to service_role;
grant all on public.sandbox_runs to service_role;
grant all on public.sandbox_results to service_role;
grant all on public.analytics_events to service_role;
grant usage, select on sequence public.admin_audit_log_id_seq to service_role;
grant usage, select on sequence public.skill_change_log_id_seq to service_role;
grant usage, select on sequence public.sandbox_results_id_seq to service_role;
grant usage, select on sequence public.analytics_events_id_seq to service_role;

-- Seed the owner used by local/build environments only when that account
-- already exists and nobody has been bootstrapped yet. A fresh production
-- database has no auth users at migration time; create the first owner
-- afterwards with the one-off insert documented in supabase/README.md.
insert into public.admin_users (user_id, role, status, mfa_required)
select 'f1b94e59-0978-4e3d-9b0c-5d6f73a24e6a', 'owner', 'active', true
where exists (
  select 1 from auth.users where id = 'f1b94e59-0978-4e3d-9b0c-5d6f73a24e6a'
)
and not exists (select 1 from public.admin_users)
on conflict (user_id) do nothing;

-- ---------------------------------------------------------------------------
-- Analytics RPCs (service role only)
-- ---------------------------------------------------------------------------

create or replace function public.admin_overview()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'onboarded', (select count(*) from public.profiles where has_completed_onboarding),
    'mentors', (select count(*) from public.profiles where role = 'mentor'),
    'learners', (select count(*) from public.profiles where role = 'learner'),
    'both', (select count(*) from public.profiles where role = 'both'),
    'new_7d', (select count(*) from public.profiles where created_at >= now() - interval '7 days'),
    'pending_requests', (select count(*) from public.connections where status = 'pending'),
    'accepted_requests', (select count(*) from public.connections where status = 'accepted'),
    'declined_requests', (select count(*) from public.connections where status = 'declined'),
    'messages', (select count(*) from public.messages),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'blocks', (select count(*) from public.blocks),
    'approved_skills', (select count(*) from public.skill_nodes where kind = 'skill' and status = 'approved'),
    'pending_skills', (select count(*) from public.skill_nodes where kind = 'skill' and status = 'pending'),
    'showcases', (select count(*) from public.skill_showcases),
    'cache_rows', (select count(*) from public.match_cache),
    'a_only_share', coalesce((select avg(case when rerank_score_b is null then 1 else 0 end) from public.match_cache), 0),
    'avg_compatibility', coalesce((select avg(calibrated_score) from public.match_cache), 0),
    'embeddings', (select count(*) from public.profile_embeddings),
    'client_errors_7d', (select count(*) from public.client_errors where created_at >= now() - interval '7 days')
  );
$$;

create or replace function public.admin_growth(p_days integer default 30)
returns table (
  day date,
  signups integer,
  completed integer,
  requests integer,
  accepted integer,
  messages integer
)
language sql
stable
security definer
set search_path = public
as $$
  with days as (
    select generate_series(
      (current_date - greatest(1, least(p_days, 365)) + 1)::date,
      current_date,
      interval '1 day'
    )::date as d
  )
  select d,
    (select count(*)::int from public.profiles p where p.created_at::date = d),
    (select count(*)::int from public.profiles p where p.has_completed_onboarding and p.updated_at::date = d),
    (select count(*)::int from public.connections c where c.created_at::date = d),
    (select count(*)::int from public.connections c where c.status = 'accepted' and c.responded_at::date = d),
    (select count(*)::int from public.messages m where m.created_at::date = d)
  from days
  order by d;
$$;

create or replace function public.admin_supply()
returns table (
  root_path text,
  root_name text,
  mentors integer,
  learners integer,
  both_roles integer,
  pending_skills integer,
  showcases integer
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select r.path::text, r.name,
    (select count(distinct us.user_id)::int from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.kind = 'teach' and n.path <@ r.path),
    (select count(distinct us.user_id)::int from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.kind = 'learn' and n.path <@ r.path),
    (select count(*)::int from public.profiles p
      where p.role = 'both'
        and exists (
          select 1 from public.user_skills us
          join public.skill_nodes n on n.id = us.skill_id
          where us.user_id = p.id and n.path <@ r.path
        )),
    (select count(*)::int from public.skill_nodes n
      where n.kind = 'skill' and n.status = 'pending' and n.path <@ r.path),
    (select count(*)::int from public.skill_showcases sc
      join public.skill_nodes n on n.id = sc.skill_id
      where n.path <@ r.path)
  from public.skill_nodes r
  where r.kind = 'category' and r.depth = 1
  order by r.name;
$$;

create or replace function public.admin_matching()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select jsonb_build_object(
    'cache_rows', (select count(*) from public.match_cache),
    'a_only_share', coalesce((select avg(case when rerank_score_b is null then 1 else 0 end) from public.match_cache), 0),
    'avg_compatibility', coalesce((select avg(calibrated_score) from public.match_cache), 0),
    'pipeline_modes', coalesce((
      select jsonb_object_agg(mode, n) from (
        select pipeline_mode as mode, count(*)::int as n
        from public.match_cache group by pipeline_mode
      ) q
    ), '{}'::jsonb),
    'score_buckets', coalesce((
      select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', n) order by bucket)
      from (
        select width_bucket(calibrated_score, 0, 1, 5) as bucket, count(*)::int as n
        from public.match_cache group by 1
      ) q
    ), '[]'::jsonb),
    'top_domains', coalesce((
      select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
      from (
        select r.name, count(*)::int as n
        from public.match_cache mc
        join public.user_skills us
          on us.user_id = mc.candidate_id
         and us.kind = case when mc.as_role = 'mentor' then 'teach'::public.skill_kind else 'learn'::public.skill_kind end
        join public.skill_nodes n on n.id = us.skill_id
        join public.skill_nodes r on r.kind = 'category' and r.depth = 1 and n.path <@ r.path
        group by r.name order by n desc limit 8
      ) q
    ), '[]'::jsonb),
    'top_skills', coalesce((
      select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
      from (
        select n.name, count(*)::int as n
        from public.match_cache mc
        join public.user_skills us
          on us.user_id = mc.candidate_id
         and us.kind = case when mc.as_role = 'mentor' then 'teach'::public.skill_kind else 'learn'::public.skill_kind end
        join public.skill_nodes n on n.id = us.skill_id
        where n.kind = 'skill'
        group by n.name order by n desc limit 8
      ) q
    ), '[]'::jsonb)
  );
$$;

create or replace function public.admin_conversations(p_days integer default 30)
returns table (
  day date,
  requests integer,
  accepted integer,
  messages integer,
  active_chats integer
)
language sql
stable
security definer
set search_path = public
as $$
  with days as (
    select generate_series(
      (current_date - greatest(1, least(p_days, 365)) + 1)::date,
      current_date,
      interval '1 day'
    )::date as d
  )
  select d,
    (select count(*)::int from public.connections c where c.created_at::date = d),
    (select count(*)::int from public.connections c where c.status = 'accepted' and c.responded_at::date = d),
    (select count(*)::int from public.messages m where m.created_at::date = d),
    (select count(distinct m.connection_id)::int from public.messages m where m.created_at::date = d)
  from days order by d;
$$;

create or replace function public.admin_safety()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'reports_open', (select count(*) from public.reports where status = 'open'),
    'reports_reviewed', (select count(*) from public.reports where status = 'reviewed'),
    'reports_dismissed', (select count(*) from public.reports where status = 'dismissed'),
    'reports_actioned', (select count(*) from public.reports where status = 'actioned'),
    'reports_by_reason', coalesce((
      select jsonb_object_agg(reason, n) from (
        select reason, count(*)::int as n from public.reports group by reason order by n desc limit 10
      ) q
    ), '{}'::jsonb),
    'blocks', (select count(*) from public.blocks),
    'pending_skills', (select count(*) from public.skill_nodes where kind = 'skill' and status = 'pending'),
    'pending_notes', (select count(*) from public.note_moderation_queue where status = 'pending'),
    'avg_resolution_hours', coalesce((
      select avg(extract(epoch from (resolved_at - created_at)) / 3600)
      from public.reports where resolved_at is not null
    ), 0),
    'repeat_reporters', coalesce((
      select count(*) from (
        select reported_id from public.reports group by reported_id having count(*) >= 3
      ) q
    ), 0)
  );
$$;

create or replace function public.admin_system()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'embeddings', (select count(*) from public.profile_embeddings),
    'cache_rows', (select count(*) from public.match_cache),
    'cache_last_refresh', (select max(refreshed_at) from public.match_cache),
    'profiles_without_embedding', (
      select count(*) from public.profiles p
      where p.has_completed_onboarding
        and not exists (select 1 from public.profile_embeddings e where e.user_id = p.id)
    ),
    'client_errors_7d', (select count(*) from public.client_errors where created_at >= now() - interval '7 days'),
    'top_client_errors', coalesce((
      select jsonb_agg(jsonb_build_object('message', message, 'count', n) order by n desc)
      from (
        select left(message, 180) as message, count(*)::int as n
        from public.client_errors
        where created_at >= now() - interval '7 days'
        group by 1 order by n desc limit 8
      ) q
    ), '[]'::jsonb),
    'rate_limit_hits', coalesce((
      select jsonb_object_agg(action, n) from (
        select action, sum(count)::int as n from public.rate_limits group by action order by n desc limit 10
      ) q
    ), '{}'::jsonb)
  );
$$;

revoke all on function public.admin_overview() from public, anon, authenticated;
revoke all on function public.admin_growth(integer) from public, anon, authenticated;
revoke all on function public.admin_supply() from public, anon, authenticated;
revoke all on function public.admin_matching() from public, anon, authenticated;
revoke all on function public.admin_conversations(integer) from public, anon, authenticated;
revoke all on function public.admin_safety() from public, anon, authenticated;
revoke all on function public.admin_system() from public, anon, authenticated;

grant execute on function public.admin_overview() to service_role;
grant execute on function public.admin_growth(integer) to service_role;
grant execute on function public.admin_supply() to service_role;
grant execute on function public.admin_matching() to service_role;
grant execute on function public.admin_conversations(integer) to service_role;
grant execute on function public.admin_safety() to service_role;
grant execute on function public.admin_system() to service_role;

-- ---------------------------------------------------------------------------
-- Admin helpers
-- ---------------------------------------------------------------------------

create or replace function public.admin_clear_mfa(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from auth.mfa_factors where user_id = p_user;
$$;

revoke all on function public.admin_clear_mfa(uuid) from public, anon, authenticated;
grant execute on function public.admin_clear_mfa(uuid) to service_role;

create or replace function public.admin_merge_skills(
  p_source uuid,
  p_target uuid,
  p_actor uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source public.skill_nodes%rowtype;
  v_target public.skill_nodes%rowtype;
  v_moved int := 0;
  v_removed int := 0;
begin
  if p_source = p_target then
    raise exception 'Source and target must differ';
  end if;
  select * into v_source from public.skill_nodes where id = p_source;
  select * into v_target from public.skill_nodes where id = p_target;
  if v_source.id is null or v_target.id is null then
    raise exception 'Skill node not found';
  end if;
  if v_source.kind <> 'skill' or v_target.kind <> 'skill' then
    raise exception 'Merge currently supports skill nodes only';
  end if;
  if exists (select 1 from public.skill_nodes where parent_id = p_source) then
    raise exception 'Move or merge child focus nodes first';
  end if;

  delete from public.user_skills s
  where s.skill_id = p_source
    and exists (
      select 1 from public.user_skills t
      where t.user_id = s.user_id
        and t.kind = s.kind
        and t.skill_id = p_target
    );
  get diagnostics v_removed = row_count;

  update public.user_skills
  set skill_id = p_target,
      focus_skill_id = null,
      updated_at = now()
  where skill_id = p_source;
  get diagnostics v_moved = row_count;

  update public.skill_nodes
  set status = 'retired',
      is_visible = false,
      updated_at = now()
  where id = p_source;

  insert into public.skill_change_log
    (node_id, action, before, after, reason, actor_id)
  values (
    p_source, 'merge',
    to_jsonb(v_source),
    jsonb_build_object('target_id', p_target, 'target_name', v_target.name,
                       'moved', v_moved, 'removed_duplicates', v_removed),
    p_reason, p_actor
  );

  return jsonb_build_object('moved', v_moved, 'removed_duplicates', v_removed);
end;
$$;

revoke all on function public.admin_merge_skills(uuid, uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_merge_skills(uuid, uuid, uuid, text)
  to service_role;
