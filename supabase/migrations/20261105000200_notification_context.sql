-- Activity rows need actor/skill context without a second client round-trip.
-- The payload stays the source of ids; joins provide current display data.

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
    c.skill_name,
    actor.role::text as role,
    c.status::text as connection_status
  from public.notifications n
  left join public.connections c
    on c.id = nullif(n.payload->>'connection_id', '')::uuid
  left join public.profiles actor
    on actor.id = case
      when n.kind = 'connection_request' then
        coalesce(
          nullif(n.payload->>'requester_id', '')::uuid,
          c.requester_id
        )
      when n.kind in ('request_accepted', 'request_declined', 'feedback_ready') then
        case
          when c.requester_id = n.user_id then c.recipient_id
          else c.requester_id
        end
      else null
    end
  where n.user_id = auth.uid()
    and (not p_unread_only or n.read_at is null)
  order by n.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
$$;

revoke all on function public.list_notifications(boolean, integer) from public;
revoke all on function public.list_notifications(boolean, integer) from anon;
grant execute on function public.list_notifications(boolean, integer) to authenticated;
grant execute on function public.list_notifications(boolean, integer) to service_role;
