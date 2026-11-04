-- C0 follow-up: the status columns are Pals-only and honor the receipt toggle.
-- Rows, unread, mute, and marked-unread behavior stay unchanged.

drop function if exists public.get_conversations();

create or replace function public.get_conversations()
returns table (
  connection_id uuid,
  status text,
  other_user_id uuid,
  other_name text,
  other_role text,
  last_message text,
  last_at timestamptz,
  unread integer,
  other_avatar text,
  other_skill text,
  muted_until timestamptz,
  marked_unread boolean,
  other_last_seen_at timestamptz,
  other_presence_enabled boolean,
  other_typing_enabled boolean,
  other_read_receipts_enabled boolean,
  other_read_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
#variable_conflict use_column
declare me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  return query
  with mine as (
    select cx.* from public.connections cx
    where cx.requester_id = me or cx.recipient_id = me
  ),
  others as (
    select m.id as conn_id, m.status as conn_status,
      case when m.requester_id = me then m.recipient_id else m.requester_id end as other_id,
      case when m.requester_id = me then m.requester_read_at else m.recipient_read_at end as my_read,
      case when m.requester_id = me then m.recipient_read_at else m.requester_read_at end as peer_read
    from mine m
  )
  select o.conn_id, o.conn_status::text, o.other_id,
    coalesce(p.display_name, ''),
    p.role::text,
    lm.body,
    lm.created_at,
    (select count(*)::int from public.messages mm
      where mm.connection_id = o.conn_id
        and mm.sender_id = o.other_id
        and mm.created_at > coalesce(o.my_read, '1970-01-01'::timestamptz))::int,
    p.avatar_url,
    coalesce(
      case
        when p.role::text = 'mentor' then (p.teaching_skills)[1]
        when p.role::text = 'learner' then (p.learning_skills)[1]
        else coalesce((p.teaching_skills)[1], (p.learning_skills)[1])
      end,
      ''
    ) as other_skill,
    cp.muted_until,
    coalesce(cp.marked_unread, false),
    case
      when o.conn_status = 'accepted' and p.presence_enabled then p.last_seen_at
      else null
    end,
    case when o.conn_status = 'accepted' then p.presence_enabled else false end,
    case when o.conn_status = 'accepted' then p.typing_enabled else false end,
    case
      when o.conn_status = 'accepted' then p.read_receipts_enabled
      else false
    end,
    case
      when o.conn_status = 'accepted' and p.read_receipts_enabled then o.peer_read
      else null
    end
  from others o
  join public.profiles p on p.id = o.other_id
  left join public.connection_preferences cp
    on cp.connection_id = o.conn_id and cp.user_id = me
  left join lateral (
    select lg.body as body, lg.created_at as created_at
    from public.messages lg
    where lg.connection_id = o.conn_id
    order by lg.created_at desc limit 1
  ) lm on true
  order by lm.created_at desc nulls last;
end
$$;

revoke all on function public.get_conversations() from public;
revoke all on function public.get_conversations() from anon;
grant execute on function public.get_conversations() to authenticated;
grant execute on function public.get_conversations() to service_role;
