-- Chat privacy contracts: presence, typing, read receipts.
-- Status data is exposed only to accepted Pals; private realtime topics are
-- restricted to the two members of the connection.

alter table public.profiles
  add column if not exists last_seen_at timestamptz,
  add column if not exists presence_enabled boolean not null default true,
  add column if not exists typing_enabled boolean not null default true,
  add column if not exists read_receipts_enabled boolean not null default true;

create or replace function public.touch_last_seen()
returns void
language sql
security definer
set search_path to 'public'
as $$
  update public.profiles
    set last_seen_at = now()
    where id = auth.uid()
      and presence_enabled;
$$;

create or replace function public.set_chat_privacy(
  p_presence boolean,
  p_typing boolean,
  p_read_receipts boolean
)
returns void
language sql
security definer
set search_path to 'public'
as $$
  update public.profiles
    set presence_enabled = coalesce(p_presence, presence_enabled),
        typing_enabled = coalesce(p_typing, typing_enabled),
        read_receipts_enabled = coalesce(p_read_receipts, read_receipts_enabled)
    where id = auth.uid();
$$;

create or replace function public.get_chat_privacy()
returns table (
  presence_enabled boolean,
  typing_enabled boolean,
  read_receipts_enabled boolean
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select p.presence_enabled, p.typing_enabled, p.read_receipts_enabled
  from public.profiles p
  where p.id = auth.uid();
$$;

create or replace function public.get_pals_presence()
returns table (
  user_id uuid,
  last_seen_at timestamptz,
  presence_enabled boolean,
  typing_enabled boolean,
  read_receipts_enabled boolean
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    p.id,
    case when p.presence_enabled then p.last_seen_at end,
    p.presence_enabled,
    p.typing_enabled,
    p.read_receipts_enabled
  from public.connections c
  join public.profiles p
    on p.id = case
      when c.requester_id = auth.uid() then c.recipient_id
      else c.requester_id
    end
  where c.status = 'accepted'
    and (c.requester_id = auth.uid() or c.recipient_id = auth.uid());
$$;

revoke all on function public.touch_last_seen() from public;
revoke all on function public.touch_last_seen() from anon;
grant execute on function public.touch_last_seen() to authenticated;
grant execute on function public.touch_last_seen() to service_role;

revoke all on function public.set_chat_privacy(boolean, boolean, boolean) from public;
revoke all on function public.set_chat_privacy(boolean, boolean, boolean) from anon;
grant execute on function public.set_chat_privacy(boolean, boolean, boolean) to authenticated;
grant execute on function public.set_chat_privacy(boolean, boolean, boolean) to service_role;

revoke all on function public.get_chat_privacy() from public;
revoke all on function public.get_chat_privacy() from anon;
grant execute on function public.get_chat_privacy() to authenticated;
grant execute on function public.get_chat_privacy() to service_role;

revoke all on function public.get_pals_presence() from public;
revoke all on function public.get_pals_presence() from anon;
grant execute on function public.get_pals_presence() to authenticated;
grant execute on function public.get_pals_presence() to service_role;

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
    case when p.presence_enabled then p.last_seen_at end,
    p.presence_enabled,
    p.typing_enabled,
    p.read_receipts_enabled,
    o.peer_read
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

-- Chat topics use unguessable connection ids. Realtime Authorization on
-- realtime.messages cannot be installed from the management/owner role used
-- here (the table is owned by supabase_realtime_admin), so membership is
-- enforced by the client: only accepted members join, and presence/typing are
-- only broadcast when the local privacy toggles allow it. Revisit with a
-- dashboard-authored policy if server-side topic ACLs become required.
