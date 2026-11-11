-- Make a block effective across transitions, cached decks, and definer reads.
--
-- The block table already existed, but block_user left a declined connection,
-- did not invalidate match_cache, and several SECURITY DEFINER RPCs joined
-- profiles without re-checking blocks. Those RPCs bypass RLS, so the new
-- profiles policy alone cannot hide a blocked pair.

-- Backfill: blocks created before this migration left declined connection
-- rows, notifications, and cached deck rows behind. Remove that legacy pair
-- state once, before the new functions take over.
delete from public.connections c
using public.blocks b
where (b.blocker_id = c.requester_id and b.blocked_id = c.recipient_id)
   or (b.blocker_id = c.recipient_id and b.blocked_id = c.requester_id);

delete from public.match_cache mc
using public.blocks b
where (b.blocker_id = mc.user_id and b.blocked_id = mc.candidate_id)
   or (b.blocker_id = mc.candidate_id and b.blocked_id = mc.user_id);

delete from public.notifications n
using public.blocks b
where n.user_id in (b.blocker_id, b.blocked_id)
  and (
    (n.payload->>'requester_id') in (b.blocker_id::text, b.blocked_id::text)
    or (n.payload->>'responder_id') in (b.blocker_id::text, b.blocked_id::text)
  );

create or replace function public.block_user(p_target uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare me uuid := auth.uid(); pair_ids uuid[];
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_target then raise exception 'You cannot block yourself'; end if;

  -- Serialize with send_connection_request for this pair so a request cannot
  -- be inserted between the block check and the block row.
  perform pg_advisory_xact_lock(
    hashtextextended(
      least(me, p_target)::text || ':' || greatest(me, p_target)::text,
      0
    )
  );

  insert into public.blocks (blocker_id, blocked_id)
    values (me, p_target) on conflict do nothing;

  -- Capture pair connection ids before deleting them so notifications can be
  -- purged by id even though notifications have no FK to connections.
  select coalesce(array_agg(id), '{}') into pair_ids
  from public.connections
  where (requester_id = me and recipient_id = p_target)
     or (requester_id = p_target and recipient_id = me);

  -- Delete connections first; cancel/undo lock the connection before the
  -- notification, so this order avoids a lock cycle.
  delete from public.connections
    where (requester_id = me and recipient_id = p_target)
       or (requester_id = p_target and recipient_id = me);

  delete from public.notifications n
  where n.user_id in (me, p_target)
    and (
      (n.payload->>'requester_id') in (me::text, p_target::text)
      or (n.payload->>'responder_id') in (me::text, p_target::text)
      or (n.payload->>'connection_id') = any(pair_ids::text[])
    );

  -- A blocked pair must not remain in either deck.
  delete from public.match_cache
    where (user_id = me and candidate_id = p_target)
       or (user_id = p_target and candidate_id = me);
end $$;

create or replace function public.undo_decline_connection(p_connection uuid)
returns table(status text)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  me uuid := auth.uid();
  c public.connections%rowtype;
begin
  if me is null then raise exception 'Not authenticated'; end if;

  select * into c
  from public.connections
  where id = p_connection
  for update;

  if not found then raise exception 'Connection not found'; end if;
  if c.recipient_id <> me then raise exception 'Only the recipient can undo a decline'; end if;
  if c.status <> 'declined' then raise exception 'Only declined requests can be reopened'; end if;
  if c.responded_at is null or c.responded_at < now() - interval '60 seconds' then
    raise exception 'The undo window has expired';
  end if;
  if public.blocked_between(me, c.requester_id) then
    raise exception 'This request is no longer available';
  end if;

  update public.connections
  set status = 'pending',
      responded_at = null,
      recipient_read_at = now()
  where id = p_connection
  returning * into c;

  delete from public.notifications
  where user_id = c.requester_id
    and kind = 'request_declined'
    and payload->>'connection_id' = p_connection::text;

  return query select c.status::text;
end;
$$;

create or replace function public.respond_connection_request(p_connection uuid, p_accept boolean)
returns table(new_status text)
language plpgsql
security definer
set search_path to 'public'
as $$
declare me uuid := auth.uid(); r public.connections%rowtype;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  select * into r from public.connections where id = p_connection for update;
  if not found then raise exception 'Connection not found'; end if;
  if r.recipient_id <> me then raise exception 'Only the recipient can respond'; end if;
  if r.status <> 'pending' then raise exception 'Request already handled'; end if;
  if public.blocked_between(me, r.requester_id) then
    raise exception 'This request is no longer available';
  end if;
  update public.connections
    set status = case when p_accept then 'accepted'::public.conn_status else 'declined'::public.conn_status end,
        responded_at = now()
    where id = p_connection and status = 'pending'
    returning * into r;
  if not found then raise exception 'Request already handled'; end if;
  perform public.notify(r.requester_id,
    case when p_accept then 'request_accepted' else 'request_declined' end,
    jsonb_build_object('connection_id', r.id, 'responder_id', me));
  return query select r.status::text;
end $$;

create or replace function public.send_message(p_connection uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare me uuid := auth.uid(); c public.connections%rowtype; mid uuid; other uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  select * into c from public.connections where id = p_connection;
  if not found then raise exception 'Connection not found'; end if;
  if c.status <> 'accepted' then raise exception 'Chat is locked until the connection is accepted'; end if;
  if c.requester_id <> me and c.recipient_id <> me then raise exception 'Not a participant'; end if;
  other := case when c.requester_id = me then c.recipient_id else c.requester_id end;
  if public.blocked_between(me, other) then raise exception 'Chat is not available'; end if;
  insert into public.messages (connection_id, sender_id, body) values (p_connection, me, btrim(p_body))
    returning id into mid;
  update public.connections
    set requester_read_at = case when requester_id = me then now() else requester_read_at end,
        recipient_read_at = case when requester_id = me then recipient_read_at else now() end
    where id = p_connection;
  perform public.check_feedback_gate(p_connection);
  return mid;
end $$;

create or replace function public.send_connection_request(
  p_recipient uuid,
  p_skill_name text default null,
  p_skill_path text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  me uuid := auth.uid();
  conn uuid;
  clean_path text := nullif(btrim(p_skill_path), '');
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_recipient then raise exception 'You cannot connect with yourself'; end if;
  if public.blocked_between(me, p_recipient) then
    raise exception 'Cannot connect with this user';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = p_recipient and has_completed_onboarding
  ) then
    raise exception 'Recipient profile is not ready';
  end if;
  if clean_path is not null and not exists (
    select 1 from public.skill_nodes where path::text = clean_path
  ) then
    raise exception 'Invalid skill context';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      least(me, p_recipient)::text || ':' || greatest(me, p_recipient)::text,
      0
    )
  );

  select id into conn from public.connections
  where (requester_id = me and recipient_id = p_recipient)
     or (requester_id = p_recipient and recipient_id = me)
  for update;

  if conn is not null then
    if public.blocked_between(me, p_recipient) then
      raise exception 'Cannot connect with this user';
    end if;
    update public.connections
    set status = 'pending',
        requester_id = me,
        recipient_id = p_recipient,
        responded_at = null,
        skill_name = coalesce(nullif(btrim(p_skill_name), ''), skill_name),
        skill_path = coalesce(clean_path, skill_path)
    where id = conn and status = 'declined';
    if not found then
      -- Keep the RPC idempotent for a retry after a lost response.
      if exists (
        select 1 from public.connections
        where id = conn and status in ('pending', 'accepted')
      ) then
        return conn;
      end if;
      raise exception 'Request state changed';
    end if;
    return conn;
  end if;

  insert into public.connections (
    requester_id,
    recipient_id,
    skill_name,
    skill_path
  )
  values (
    me,
    p_recipient,
    nullif(btrim(p_skill_name), ''),
    clean_path
  )
  returning id into conn;

  -- Close the insert race: if a block committed while this row was being
  -- created, remove it and fail.
  if public.blocked_between(me, p_recipient) then
    delete from public.connections where id = conn;
    raise exception 'Cannot connect with this user';
  end if;

  perform public.notify(
    p_recipient,
    'connection_request',
    jsonb_build_object('connection_id', conn, 'requester_id', me)
  );
  return conn;
end;
$$;

drop function if exists public.send_connection_request(uuid);

create or replace function public.get_outgoing_requests(p_limit integer default 25)
returns table (
  connection_id uuid,
  recipient_id uuid,
  recipient_name text,
  avatar_url text,
  skills text[],
  status text,
  created_at timestamp with time zone
)
language sql
stable
security definer
set search_path = public
as $$
with mine as (
  select * from public.connections
  where requester_id = auth.uid()
    and status in ('pending', 'declined')
),
sk as (
  select us.user_id,
    coalesce(array_agg(distinct n.name order by n.name), '{}') as skills
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  group by us.user_id
)
select
  m.id,
  m.recipient_id,
  coalesce(p.display_name, ''),
  p.avatar_url,
  sk.skills,
  m.status::text,
  m.created_at
from mine m
join public.profiles p on p.id = m.recipient_id
left join sk on sk.user_id = m.recipient_id
where not public.blocked_between(auth.uid(), m.recipient_id)
order by m.created_at desc
limit greatest(1, least(p_limit, 100));
$$;

drop function if exists public.get_incoming_requests(integer);

create or replace function public.get_incoming_requests(p_limit integer default 25)
returns table (
  connection_id uuid,
  requester_id uuid,
  requester_name text,
  requester_role text,
  avatar_url text,
  skills text[],
  requested_skill_name text,
  requested_skill_path text,
  in_declared_domain boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $$
with mine as (
  select * from public.connections
  where recipient_id = auth.uid() and status = 'pending'
),
sk as (
  select us.user_id,
    coalesce(array_agg(distinct n.name order by n.name), '{}') as skills
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  group by us.user_id
)
select
  m.id,
  m.requester_id,
  coalesce(p.display_name, ''),
  p.role::text,
  p.avatar_url,
  sk.skills,
  coalesce(m.skill_name, (sk.skills)[1]),
  m.skill_path,
  case
    when m.skill_path is null
      or m.skill_path !~ '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*$'
      then null
    else exists (
      select 1
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.user_id = auth.uid()
        and n.path @> m.skill_path::extensions.ltree
    )
  end,
  m.created_at
from mine m
join public.profiles p on p.id = m.requester_id
left join sk on sk.user_id = m.requester_id
where not public.blocked_between(auth.uid(), m.requester_id)
order by m.created_at desc
limit greatest(1, least(coalesce(p_limit, 25), 100));
$$;

create or replace function public.get_conversation(p_connection uuid, p_limit integer default 200)
returns table (id uuid, sender_id uuid, body text, created_at timestamptz)
language plpgsql
security definer
set search_path to 'public'
as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  c public.connections%rowtype;
  other uuid;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  select * into c from public.connections where connections.id = p_connection;
  if not found then raise exception 'Connection not found'; end if;
  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;
  other := case when c.requester_id = me then c.recipient_id else c.requester_id end;
  if public.blocked_between(me, other) then
    raise exception 'Chat is not available';
  end if;
  if c.requester_id = me then
    update public.connections set requester_read_at = now()
    where connections.id = p_connection;
  else
    update public.connections set recipient_read_at = now()
    where connections.id = p_connection;
  end if;
  return query
    select msg.id, msg.sender_id, msg.body, msg.created_at
    from public.messages msg
    where msg.connection_id = p_connection
    order by msg.created_at desc
    limit greatest(1, least(coalesce(p_limit, 200), 200));
end
$$;

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
    where (cx.requester_id = me or cx.recipient_id = me)
      and not public.blocked_between(
        me,
        case when cx.requester_id = me then cx.recipient_id else cx.requester_id end
      )
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
        coalesce(
          case
            when c.requester_id = n.user_id then c.recipient_id
            else c.requester_id
          end,
          nullif(n.payload->>'responder_id', '')::uuid
        )
      else null
    end
  where n.user_id = auth.uid()
    and (not p_unread_only or n.read_at is null)
    and (actor.id is null or not public.blocked_between(auth.uid(), actor.id))
  order by n.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
$$;

revoke all on function public.get_outgoing_requests(integer) from public, anon;
grant execute on function public.get_outgoing_requests(integer) to authenticated;
revoke all on function public.get_incoming_requests(integer) from public, anon;
grant execute on function public.get_incoming_requests(integer) to authenticated, service_role;
revoke all on function public.get_conversations() from public, anon;
grant execute on function public.get_conversations() to authenticated, service_role;
revoke all on function public.list_notifications(boolean, integer) from public, anon;
grant execute on function public.list_notifications(boolean, integer) to authenticated, service_role;

create or replace function public.cache_is_fresh(
  p_user uuid,
  p_role public.embed_role,
  p_revision integer
)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    not exists (
      select 1
      from public.blocks b
      join public.match_cache blocked
        on blocked.user_id = p_user
       and blocked.as_role = p_role
      where (b.blocker_id = p_user and b.blocked_id = blocked.candidate_id)
         or (b.blocker_id = blocked.candidate_id and b.blocked_id = p_user)
    )
    and exists (
      select 1
      from public.match_cache mc
      join public.profiles own on own.id = mc.user_id
      where mc.user_id = p_user and mc.as_role = p_role
        and mc.config_version = p_revision
        and mc.refreshed_at > own.updated_at
        and not exists (
          select 1 from public.user_skills ownus
          where ownus.user_id = p_user and ownus.updated_at > mc.refreshed_at
        )
        and not exists (
          select 1 from public.profiles cand
          join public.match_cache m2 on m2.user_id = mc.user_id and m2.as_role = mc.as_role
          where cand.id = m2.candidate_id and cand.updated_at > m2.refreshed_at
        )
        and not exists (
          select 1 from public.user_skills cs
          join public.match_cache m3 on m3.user_id = mc.user_id and m3.as_role = mc.as_role
          where cs.user_id = m3.candidate_id and cs.updated_at > m3.refreshed_at
        )
    )
$$;
