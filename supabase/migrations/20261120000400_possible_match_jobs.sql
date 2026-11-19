-- Possible match notifications, phase 1: durable jobs, audit events, and the
-- enqueue path.
--
-- This is deliberately SQL-first. A profile/skill/showcase edit only records a
-- debounced job; the cron worker in 20261120000500 decides whether the change
-- is actually a new possible match for anyone. That keeps profile writes cheap
-- and makes the fan-out retryable without an Edge Function or a new secret.

create table if not exists public.possible_match_jobs (
  id bigserial primary key,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default 'profile_update'
    check (reason in ('new_profile','profile_update','skills','context','media','manual')),
  status text not null default 'pending'
    check (status in ('pending','processing','done','failed','skipped')),
  attempts integer not null default 0,
  run_after timestamptz not null default now(),
  locked_at timestamptz,
  last_error text,
  notifications_created integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists possible_match_jobs_active
  on public.possible_match_jobs (candidate_id)
  where status in ('pending','processing');

create index if not exists possible_match_jobs_due
  on public.possible_match_jobs (run_after)
  where status = 'pending';

create index if not exists possible_match_jobs_created
  on public.possible_match_jobs (created_at desc);

create table if not exists public.possible_match_events (
  id bigserial primary key,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  as_role public.embed_role not null,
  score real not null default 0,
  skill_name text,
  skill_path text,
  status text not null default 'shadow'
    check (status in ('shadow','notified','suppressed')),
  suppressed_reason text,
  last_notified_at timestamptz,
  notification_id uuid references public.notifications(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recipient_id, candidate_id)
);

create index if not exists possible_match_events_candidate
  on public.possible_match_events (candidate_id, created_at desc);
create index if not exists possible_match_events_recipient
  on public.possible_match_events (recipient_id, last_notified_at desc);

-- Internal tables. The cron worker runs as the database owner; clients have no
-- business reading who was considered for a notification.
alter table public.possible_match_jobs enable row level security;
alter table public.possible_match_events enable row level security;

revoke all on public.possible_match_jobs from public, anon, authenticated;
revoke all on public.possible_match_events from public, anon, authenticated;
grant all on public.possible_match_jobs to service_role;
grant all on public.possible_match_events to service_role;
grant usage, select on sequence public.possible_match_jobs_id_seq to service_role;
grant usage, select on sequence public.possible_match_events_id_seq to service_role;

-- Keep the notification table honest about the new kind. The app is deployed
-- before live mode is enabled, so an older client never sees an unknown kind.
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind = any (array[
    'connection_request','request_accepted','request_declined',
    'feedback_ready','skill_moderation','possible_match'
  ]::text[]));

-- Rollout knobs. `on conflict do nothing` keeps an operator's tuned values if a
-- later migration is replayed.
insert into public.pipeline_config (key, value, description, config_version)
values
  ('possible_match_enabled', to_jsonb(true),
   'Master switch for possible-match fan-out', 1),
  ('possible_match_mode', to_jsonb('shadow'::text),
   'Possible-match mode: off, shadow (record only), or live', 1),
  ('possible_match_debounce_seconds', to_jsonb(45),
   'Coalesce repeated profile edits into one job', 1),
  ('possible_match_jobs_per_run', to_jsonb(20),
   'Maximum jobs claimed by one cron invocation', 1),
  ('possible_match_recipients_per_job', to_jsonb(100),
   'Maximum recipients notified for one candidate job', 1),
  ('possible_match_recall_k', to_jsonb(200),
   'Nearest viewers retrieved per embedding direction', 1),
  ('possible_match_min_score', to_jsonb(0.12),
   'Minimum cosine score for an embedding-based possible match', 1),
  ('possible_match_fallback_score', to_jsonb(0.12),
   'Score assigned to an exact skill-overlap fallback pair', 1),
  ('possible_match_cooldown_days', to_jsonb(60),
   'Do not notify the same pair again inside this window', 1),
  ('possible_match_daily_cap', to_jsonb(3),
   'Maximum possible matches per recipient per rolling 24 hours', 1),
  ('possible_match_weekly_cap', to_jsonb(10),
   'Maximum possible matches per recipient per rolling 7 days', 1),
  ('possible_match_max_attempts', to_jsonb(5),
   'Failed attempts before a job is marked failed', 1),
  ('possible_match_skill_fallback', to_jsonb(true),
   'Allow exact skill-overlap matches when embeddings are absent', 1),
  ('possible_match_job_lock_minutes', to_jsonb(5),
   'Reap a processing job after this many minutes', 1),
  ('possible_match_inactive_days', to_jsonb(0),
   'Skip recipients unseen for N days; 0 disables the filter', 1),
  ('possible_match_retention_days', to_jsonb(90),
   'Delete read possible-match notifications after N days', 1)
on conflict (key) do nothing;

create or replace function public.enqueue_possible_match_job(
  p_candidate uuid,
  p_reason text default 'profile_update'
)
returns void
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_reason text;
  v_debounce integer;
begin
  if p_candidate is null then return; end if;

  v_reason := case
    when p_reason in ('new_profile','profile_update','skills','context','media','manual')
      then p_reason
    else 'profile_update'
  end;

  -- A missing/incomplete profile cannot be a candidate yet. A suspended or
  -- banned profile is cleaned up by 20261120000600; enqueueing would only
  -- create retries that can never succeed.
  if not exists (
    select 1 from public.profiles p
    where p.id = p_candidate
      and coalesce(p.has_completed_onboarding, false)
      and p.moderation_status = 'active'
  ) then
    return;
  end if;

  v_debounce := greatest(0, coalesce((
    select (value #>> '{}')::int from public.pipeline_config
    where key = 'possible_match_debounce_seconds'
  ), 45));

  update public.possible_match_jobs
  set run_after = now() + make_interval(secs => v_debounce),
      reason = v_reason,
      updated_at = now()
  where candidate_id = p_candidate
    and status in ('pending','processing');

  if found then return; end if;

  insert into public.possible_match_jobs (candidate_id, reason, run_after)
  values (p_candidate, v_reason, now() + make_interval(secs => v_debounce))
  on conflict (candidate_id) where status in ('pending','processing')
  do update set
    run_after = now() + make_interval(secs => v_debounce),
    reason = excluded.reason,
    updated_at = now();
end;
$$;

revoke all on function public.enqueue_possible_match_job(uuid, text)
  from public, anon, authenticated;
grant execute on function public.enqueue_possible_match_job(uuid, text)
  to service_role;

-- Profile changes that alter matching context. Skills are intentionally not in
-- this list: user_skills is the source of truth and syncs the arrays, so a
-- skill edit would otherwise enqueue twice.
create or replace function public.possible_match_enqueue_profile()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  perform public.enqueue_possible_match_job(
    new.id,
    case
      when tg_op = 'INSERT' then 'new_profile'
      when coalesce(new.has_completed_onboarding, false)
        and not coalesce(old.has_completed_onboarding, false)
        then 'new_profile'
      else 'profile_update'
    end
  );
  return null;
end;
$$;

drop trigger if exists possible_match_enqueue_profile on public.profiles;
create trigger possible_match_enqueue_profile
  after insert or update of
    role, languages, teaching_styles, learning_styles, availability,
    has_completed_onboarding, moderation_status, photos, teaching_skill_images
  on public.profiles
  for each row execute function public.possible_match_enqueue_profile();

create or replace function public.possible_match_enqueue_skill()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  perform public.enqueue_possible_match_job(
    case when tg_op = 'DELETE' then old.user_id else new.user_id end,
    'skills'
  );
  return null;
end;
$$;

drop trigger if exists possible_match_enqueue_skill on public.user_skills;
create trigger possible_match_enqueue_skill
  after insert or update or delete on public.user_skills
  for each row execute function public.possible_match_enqueue_skill();

-- Adding or removing showcase media can make a mentor discoverable (or hide
-- them). This is the only media signal the matcher treats as a hard gate.
create or replace function public.possible_match_enqueue_media()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  perform public.enqueue_possible_match_job(
    case when tg_op = 'DELETE' then old.user_id else new.user_id end,
    'media'
  );
  return null;
end;
$$;

drop trigger if exists possible_match_enqueue_media on public.skill_showcases;
create trigger possible_match_enqueue_media
  after insert or delete on public.skill_showcases
  for each row execute function public.possible_match_enqueue_media();
