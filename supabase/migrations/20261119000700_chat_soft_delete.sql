-- D2: chat clearing is per user, and unmatch keeps the message rows for the
-- peer and for moderation instead of cascading a hard delete.
alter table public.connections
  add column if not exists requester_cleared_at timestamptz,
  add column if not exists recipient_cleared_at timestamptz,
  add column if not exists unmatched_at timestamptz;

-- Clear the thread for the caller only. Messages stay in place so the peer and
-- moderation can still see them.
create or replace function public.delete_conversation(p_connection uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  c public.connections%rowtype;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  if p_connection is null then
    raise exception 'Conversation is required';
  end if;

  select * into c from public.connections where id = p_connection;
  if not found then
    return;
  end if;
  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;

  update public.connections
  set requester_cleared_at =
        case when requester_id = me then now() else requester_cleared_at end,
      recipient_cleared_at =
        case when recipient_id = me then now() else recipient_cleared_at end
  where id = p_connection;
end;
$$;

revoke all on function public.delete_conversation(uuid) from public, anon;
grant execute on function public.delete_conversation(uuid)
  to authenticated, service_role;

-- Unmatch hides the conversation for both sides but keeps the connection and
-- message rows for reports and moderation.
create or replace function public.unmatch_connection(p_connection uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  c public.connections%rowtype;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  if p_connection is null then
    raise exception 'Connection is required';
  end if;

  select * into c from public.connections where id = p_connection;
  if not found then
    return;
  end if;
  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;
  if c.status <> 'accepted' then
    raise exception 'Only accepted connections can be unmatched';
  end if;
  if c.unmatched_at is not null then
    return;
  end if;

  update public.connections
  set unmatched_at = now()
  where id = p_connection;
end;
$$;

revoke all on function public.unmatch_connection(uuid) from public, anon;
grant execute on function public.unmatch_connection(uuid)
  to authenticated, service_role;

-- Conversations the caller has cleared stay hidden until a new message arrives
-- after the clear timestamp; only messages after that point are returned.
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
      and cx.unmatched_at is null
      and not public.blocked_between(
        me,
        case when cx.requester_id = me then cx.recipient_id else cx.requester_id end
      )
  ),
  others as (
    select m.id as conn_id, m.status as conn_status,
      case when m.requester_id = me then m.recipient_id else m.requester_id end as other_id,
      case when m.requester_id = me then m.requester_read_at else m.recipient_read_at end as my_read,
      case when m.requester_id = me then m.recipient_read_at else m.requester_read_at end as peer_read,
      case when m.requester_id = me then m.requester_cleared_at else m.recipient_cleared_at end as my_cleared
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
        and mm.created_at > greatest(
          coalesce(o.my_read, '1970-01-01'::timestamptz),
          coalesce(o.my_cleared, '1970-01-01'::timestamptz)
        ))::int,
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
      and (o.my_cleared is null or lg.created_at > o.my_cleared)
    order by lg.created_at desc limit 1
  ) lm on true
  where o.my_cleared is null
     or exists (
       select 1 from public.messages m2
       where m2.connection_id = o.conn_id
         and m2.created_at > o.my_cleared
     )
  order by lm.created_at desc nulls last;
end
$$;

revoke all on function public.get_conversations() from public, anon;
grant execute on function public.get_conversations()
  to authenticated, service_role;

create or replace function public.get_conversation(
  p_connection uuid,
  p_limit integer default 200
)
returns table (
  id uuid,
  sender_id uuid,
  body text,
  created_at timestamp with time zone,
  deleted_at timestamp with time zone,
  edited_at timestamp with time zone
)
language plpgsql
security definer
set search_path to 'public'
as $function$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  c public.connections%rowtype;
  other uuid;
  my_cleared timestamptz;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  select * into c from public.connections where connections.id = p_connection;
  if not found then raise exception 'Connection not found'; end if;
  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;
  if c.unmatched_at is not null then
    raise exception 'Chat is not available';
  end if;
  other := case when c.requester_id = me then c.recipient_id else c.requester_id end;
  if public.blocked_between(me, other) then
    raise exception 'Chat is not available';
  end if;
  my_cleared := case
    when c.requester_id = me then c.requester_cleared_at
    else c.recipient_cleared_at
  end;
  if c.requester_id = me then
    update public.connections set requester_read_at = now()
    where connections.id = p_connection;
  else
    update public.connections set recipient_read_at = now()
    where connections.id = p_connection;
  end if;
  return query
    select msg.id, msg.sender_id, msg.body, msg.created_at, msg.deleted_at, msg.edited_at
    from public.messages msg
    where msg.connection_id = p_connection
      and (my_cleared is null or msg.created_at > my_cleared)
    order by msg.created_at desc
    limit greatest(1, least(coalesce(p_limit, 200), 200));
end
$function$;

revoke all on function public.get_conversation(uuid, integer) from public, anon;
grant execute on function public.get_conversation(uuid, integer)
  to authenticated, service_role;

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
  if c.unmatched_at is not null then raise exception 'Chat is not available'; end if;
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

revoke all on function public.send_message(uuid, text) from public, anon;
grant execute on function public.send_message(uuid, text)
  to authenticated, service_role;

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
    and c.unmatched_at is null
    and (c.requester_id = auth.uid() or c.recipient_id = auth.uid());
$$;

revoke all on function public.get_pals_presence() from public, anon;
grant execute on function public.get_pals_presence()
  to authenticated, service_role;

-- Reports keep a snapshot of the last 50 messages so moderation can still see
-- context after either side clears or unmatches the conversation.
alter table public.reports
  add column if not exists messages_snapshot jsonb;

create or replace function public.report_user(
  p_target uuid,
  p_reason text,
  p_details text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  v_connection uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_target then raise exception 'You cannot report yourself'; end if;

  select c.id into v_connection
  from public.connections c
  where ((c.requester_id = me and c.recipient_id = p_target)
      or (c.requester_id = p_target and c.recipient_id = me))
    and c.status = 'accepted'
  order by c.created_at desc
  limit 1;

  insert into public.reports (
    reporter_id, reported_id, reason, details, messages_snapshot
  )
  values (
    me,
    p_target,
    btrim(p_reason),
    p_details,
    case
      when v_connection is null then null
      else (
        select jsonb_agg(
          jsonb_build_object(
            'sender_id', m.sender_id,
            'body', m.body,
            'created_at', m.created_at
          )
          order by m.created_at
        )
        from (
          select * from public.messages
          where connection_id = v_connection
          order by created_at desc
          limit 50
        ) m
      )
    end
  );
end;
$$;

revoke all on function public.report_user(uuid, text, text) from public, anon;
grant execute on function public.report_user(uuid, text, text)
  to authenticated, service_role;
