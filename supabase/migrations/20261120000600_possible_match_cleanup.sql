-- Possible match notifications, phase 3: read path and lifecycle cleanup.
--
-- A possible match is only useful while the candidate is still a real,
-- visible profile. Connections, blocks, reports, moderation changes, and
-- profile deletion must remove or suppress the row instead of leaving a dead
-- "View profile" action in Activity.

create index if not exists notifications_possible_match_user_created
  on public.notifications (user_id, created_at desc)
  where kind = 'possible_match';

create index if not exists notifications_possible_match_read
  on public.notifications (read_at)
  where kind = 'possible_match';

drop function if exists public.list_notifications(boolean, integer);

create or replace function public.list_notifications(
  p_unread_only boolean default false,
  p_limit integer default 30
)
returns table (
  id uuid,
  kind text,
  payload jsonb,
  read_at timestamptz,
  created_at timestamptz,
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
set search_path to 'public'
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
  order by n.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
$$;

revoke all on function public.list_notifications(boolean, integer)
  from public, anon;
grant execute on function public.list_notifications(boolean, integer)
  to authenticated;

-- A connection, block, or report is a hard stop for the pair. Delete the
-- actionable notification and mark the audit event. Keep last_notified_at so
-- the pair cooldown still applies if the block is later removed.
create or replace function public.cleanup_possible_match_pair()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_a uuid;
  v_b uuid;
  v_reason text;
begin
  if tg_table_name = 'connections' then
    v_a := coalesce(new.requester_id, old.requester_id);
    v_b := coalesce(new.recipient_id, old.recipient_id);
    v_reason := 'connected';
  elsif tg_table_name = 'blocks' then
    v_a := coalesce(new.blocker_id, old.blocker_id);
    v_b := coalesce(new.blocked_id, old.blocked_id);
    v_reason := 'blocked';
  elsif tg_table_name = 'reports' then
    v_a := coalesce(new.reporter_id, old.reporter_id);
    v_b := coalesce(new.reported_id, old.reported_id);
    v_reason := 'reported';
  else
    return null;
  end if;

  if v_a is null or v_b is null or v_a = v_b then return null; end if;

  delete from public.notifications n
  where n.kind = 'possible_match'
    and (
      (n.user_id = v_a and n.payload ->> 'candidate_id' = v_b::text)
      or (n.user_id = v_b and n.payload ->> 'candidate_id' = v_a::text)
    );

  update public.possible_match_events e
  set status = 'suppressed',
      suppressed_reason = v_reason,
      notification_id = null,
      updated_at = now()
  where (e.recipient_id = v_a and e.candidate_id = v_b)
     or (e.recipient_id = v_b and e.candidate_id = v_a);

  return null;
end;
$$;

drop trigger if exists possible_match_cleanup_connections on public.connections;
create trigger possible_match_cleanup_connections
  after insert or update or delete on public.connections
  for each row execute function public.cleanup_possible_match_pair();

drop trigger if exists possible_match_cleanup_blocks on public.blocks;
create trigger possible_match_cleanup_blocks
  after insert or update or delete on public.blocks
  for each row execute function public.cleanup_possible_match_pair();

drop trigger if exists possible_match_cleanup_reports on public.reports;
create trigger possible_match_cleanup_reports
  after insert or update or delete on public.reports
  for each row execute function public.cleanup_possible_match_pair();

create or replace function public.cleanup_possible_match_profile()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.notifications
    where kind = 'possible_match'
      and payload ->> 'candidate_id' = old.id::text;
    return old;
  end if;

  if new.moderation_status is distinct from 'active' then
    -- This profile can no longer be suggested.
    delete from public.notifications
    where kind = 'possible_match'
      and payload ->> 'candidate_id' = new.id::text;

    update public.possible_match_events
    set status = 'suppressed',
        suppressed_reason = 'candidate_inactive',
        notification_id = null,
        updated_at = now()
    where candidate_id = new.id;

    -- ...and this profile should not keep suggestions either.
    delete from public.notifications
    where kind = 'possible_match'
      and user_id = new.id;

    update public.possible_match_events
    set status = 'suppressed',
        suppressed_reason = 'recipient_inactive',
        notification_id = null,
        updated_at = now()
    where recipient_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists possible_match_cleanup_profile_status on public.profiles;
create trigger possible_match_cleanup_profile_status
  after update of moderation_status on public.profiles
  for each row execute function public.cleanup_possible_match_profile();

drop trigger if exists possible_match_cleanup_profile_delete on public.profiles;
create trigger possible_match_cleanup_profile_delete
  after delete on public.profiles
  for each row execute function public.cleanup_possible_match_profile();
