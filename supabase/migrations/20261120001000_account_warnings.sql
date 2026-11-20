-- Account warnings: user-visible notices with a retention window.
--
-- A warning is visible in the consumer app until visible_until, then it
-- disappears from the user's surfaces. The row is never deleted: admins keep
-- the full history and profiles.warning_count keeps counting every
-- non-revoked warning for future judgments.

create table if not exists public.account_warnings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  report_id uuid references public.reports(id) on delete set null,
  category text not null default 'other'
    check (category in ('spam', 'harassment', 'irrelevant', 'other')),
  message text not null check (char_length(message) between 1 and 500),
  internal_reason text,
  visible_days integer not null default 30
    check (visible_days between 1 and 365),
  visible_until timestamptz not null,
  issued_by uuid,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid,
  revoke_reason text
);

create index if not exists account_warnings_user_idx
  on public.account_warnings (user_id, created_at desc);

-- One active warning per report; retries cannot double-warn.
create unique index if not exists account_warnings_active_report_idx
  on public.account_warnings (report_id)
  where report_id is not null and revoked_at is null;

alter table public.account_warnings enable row level security;
revoke all on public.account_warnings from public, anon, authenticated;

-- Allow the new notification kind. Existing values are preserved.
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in (
    'connection_request',
    'request_accepted',
    'request_declined',
    'feedback_ready',
    'skill_moderation',
    'possible_match',
    'account_warning'
  ));

-- Keep the legacy counter truthful. It counts retained warnings, including
-- ones the user can no longer see, because future moderation reads it.
create or replace function public.sync_account_warning_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  target := case when tg_op = 'DELETE' then old.user_id else new.user_id end;

  update public.profiles p
  set warning_count = (
        select count(*) from public.account_warnings w
        where w.user_id = target and w.revoked_at is null
      ),
      last_warned_at = (
        select max(w.created_at) from public.account_warnings w
        where w.user_id = target and w.revoked_at is null
      )
  where p.id = target;

  return null;
end;
$$;

drop trigger if exists account_warnings_count on public.account_warnings;
create trigger account_warnings_count
after insert or update of revoked_at or delete on public.account_warnings
for each row execute function public.sync_account_warning_count();

-- Service-only: record a warning, notify the user, and let the trigger update
-- the counter. Returns the warning id and the visibility deadline.
create or replace function public.admin_issue_warning(
  p_user uuid,
  p_report uuid,
  p_category text,
  p_message text,
  p_internal_reason text,
  p_visible_days integer,
  p_actor uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_days integer;
  v_until timestamptz;
  v_count integer;
  v_category text;
begin
  if p_user is null then
    raise exception 'User is required';
  end if;
  if p_message is null or char_length(btrim(p_message)) = 0 then
    raise exception 'A message for the user is required';
  end if;
  if char_length(btrim(p_message)) > 500 then
    raise exception 'Message must be 500 characters or fewer';
  end if;

  v_category := case
    when p_category in ('spam', 'harassment', 'irrelevant', 'other') then p_category
    else 'other'
  end;
  v_days := greatest(1, least(coalesce(p_visible_days, 30), 365));

  if p_report is not null and exists (
    select 1 from public.account_warnings w
    where w.report_id = p_report and w.revoked_at is null
  ) then
    raise exception 'This report already has an active warning';
  end if;

  insert into public.account_warnings (
    user_id, report_id, category, message, internal_reason,
    visible_days, visible_until, issued_by
  )
  values (
    p_user, p_report, v_category, btrim(p_message),
    nullif(btrim(coalesce(p_internal_reason, '')), ''),
    v_days, now() + make_interval(days => v_days), p_actor
  )
  returning id, visible_until into v_id, v_until;

  select count(*)::int into v_count
  from public.account_warnings
  where user_id = p_user and revoked_at is null;

  insert into public.notifications (user_id, kind, payload)
  values (
    p_user,
    'account_warning',
    jsonb_build_object(
      'warning_id', v_id,
      'category', v_category,
      'message', btrim(p_message),
      'visible_until', v_until,
      'count', v_count,
      'issued_at', now()
    )
  );

  return jsonb_build_object(
    'id', v_id,
    'visible_until', v_until,
    'visible_days', v_days,
    'warning_count', v_count
  );
end;
$$;

revoke all on function public.admin_issue_warning(uuid, uuid, text, text, text, integer, uuid)
  from public, anon, authenticated;
grant execute on function public.admin_issue_warning(uuid, uuid, text, text, text, integer, uuid)
  to service_role;

-- User-facing: only warnings still inside their visibility window.
create or replace function public.get_my_warnings()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', w.id,
        'category', w.category,
        'message', w.message,
        'created_at', w.created_at,
        'visible_until', w.visible_until,
        'acknowledged_at', w.acknowledged_at
      )
      order by w.created_at desc
    ),
    '[]'::jsonb
  )
  from public.account_warnings w
  where w.user_id = auth.uid()
    and w.revoked_at is null
    and w.visible_until > now();
$$;

revoke all on function public.get_my_warnings() from public, anon;
grant execute on function public.get_my_warnings() to authenticated;

create or replace function public.acknowledge_warning(p_warning uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  update public.account_warnings
  set acknowledged_at = coalesce(acknowledged_at, now())
  where id = p_warning
    and user_id = auth.uid()
    and revoked_at is null;
  return found;
end;
$$;

revoke all on function public.acknowledge_warning(uuid) from public, anon;
grant execute on function public.acknowledge_warning(uuid) to authenticated;

-- Service-only: hide a warning immediately. The row and its counters remain
-- for admin history; only the user-facing notice is revoked.
create or replace function public.admin_revoke_warning(
  p_warning uuid,
  p_actor uuid,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
begin
  update public.account_warnings
  set revoked_at = now(),
      revoked_by = p_actor,
      revoke_reason = nullif(btrim(coalesce(p_reason, '')), '')
  where id = p_warning and revoked_at is null
  returning user_id into v_user;

  if v_user is null then
    return false;
  end if;

  delete from public.notifications n
  where n.user_id = v_user
    and n.kind = 'account_warning'
    and (n.payload ->> 'warning_id') = p_warning::text;

  return true;
end;
$$;

revoke all on function public.admin_revoke_warning(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_revoke_warning(uuid, uuid, text) to service_role;

-- Hide warning notifications once their window closes or they are revoked.
-- This is the only change to the existing notification RPC.
create or replace function public.list_notifications(
  p_unread_only boolean default false,
  p_limit integer default 30
)
returns table (
  id uuid,
  kind text,
  payload jsonb,
  read_at timestamp with time zone,
  created_at timestamp with time zone,
  actor_id uuid,
  actor_name text,
  actor_avatar text,
  skill_name text,
  role text,
  connection_status text
)
language sql
stable
security definer
set search_path = 'public'
as $$
  select
    n.id,
    n.kind,
    n.payload,
    n.read_at,
    n.created_at,
    actor.id as actor_id,
    actor.display_name as actor_name,
    actor.avatar_url as actor_avatar,
    coalesce(
      c.skill_name,
      case
        when n.kind = 'possible_match'
          then nullif(n.payload ->> 'skill_name', '')
      end
    ) as skill_name,
    actor.role::text as role,
    case
      when n.kind = 'possible_match' then null
      else c.status::text
    end as connection_status
  from public.notifications n
  left join public.connections c
    on c.id = nullif(n.payload ->> 'connection_id', '')::uuid
  left join public.profiles actor
    on actor.id = case
      when n.kind = 'connection_request' then
        coalesce(
          nullif(n.payload ->> 'requester_id', '')::uuid,
          c.requester_id
        )
      when n.kind in ('request_accepted', 'request_declined', 'feedback_ready') then
        coalesce(
          case
            when c.requester_id = n.user_id then c.recipient_id
            else c.requester_id
          end,
          nullif(n.payload ->> 'responder_id', '')::uuid
        )
      when n.kind = 'possible_match' then
        nullif(n.payload ->> 'candidate_id', '')::uuid
      else null
    end
  where n.user_id = auth.uid()
    and (not p_unread_only or n.read_at is null)
    and (actor.id is null or not public.blocked_between(auth.uid(), actor.id))
    and (
      n.kind <> 'possible_match'
      or (
        actor.id is not null
        and actor.id <> n.user_id
        and coalesce(actor.has_completed_onboarding, false)
        and actor.moderation_status = 'active'
        and (
          n.payload ->> 'as_role' <> 'mentor'
          or public.has_discovery_media(actor.id)
        )
        and not exists (
          select 1 from public.connections conn
          where (conn.requester_id = n.user_id and conn.recipient_id = actor.id)
             or (conn.requester_id = actor.id and conn.recipient_id = n.user_id)
        )
        and not exists (
          select 1 from public.reports rep
          where (rep.reporter_id = n.user_id and rep.reported_id = actor.id)
             or (rep.reporter_id = actor.id and rep.reported_id = n.user_id)
        )
      )
    )
    and (
      n.kind <> 'account_warning'
      or exists (
        select 1
        from public.account_warnings w
        where w.id = nullif(n.payload ->> 'warning_id', '')::uuid
          and w.user_id = n.user_id
          and w.revoked_at is null
          and w.visible_until > now()
      )
    )
  order by n.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
$$;

revoke all on function public.list_notifications(boolean, integer)
  from public, anon, authenticated;
grant execute on function public.list_notifications(boolean, integer) to authenticated;

-- Keep the unread badge consistent with the filtered list.
create or replace function public.count_unread_notifications()
returns integer
language sql
stable
security definer
set search_path = 'public'
as $$
  select count(*)::int
  from public.notifications n
  where n.user_id = auth.uid()
    and n.read_at is null
    and (
      n.kind <> 'account_warning'
      or exists (
        select 1
        from public.account_warnings w
        where w.id = nullif(n.payload ->> 'warning_id', '')::uuid
          and w.user_id = n.user_id
          and w.revoked_at is null
          and w.visible_until > now()
      )
    );
$$;

revoke all on function public.count_unread_notifications() from public, anon, authenticated;
grant execute on function public.count_unread_notifications() to authenticated;
