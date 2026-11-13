-- Deleted messages become tombstones so a sender cannot remove context from
-- the thread. The body is replaced and the row is marked, not removed.

alter table public.messages
  add column if not exists deleted_at timestamp with time zone;

drop function if exists public.delete_message(uuid);

create or replace function public.delete_message(p_message uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  m public.messages%rowtype;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  if p_message is null then
    raise exception 'Message is required';
  end if;

  select * into m from public.messages where id = p_message;
  if not found then
    return;
  end if;
  if m.sender_id <> me then
    raise exception 'Only the sender can delete this message';
  end if;
  if m.deleted_at is not null then
    return;
  end if;

  update public.messages
    set body = 'Message Deleted', deleted_at = now()
    where id = p_message;
end;
$$;

revoke all on function public.delete_message(uuid) from public, anon;
grant execute on function public.delete_message(uuid) to authenticated, service_role;

drop function if exists public.get_conversation(uuid, integer);

create or replace function public.get_conversation(
  p_connection uuid,
  p_limit integer default 200
)
returns table (
  id uuid,
  sender_id uuid,
  body text,
  created_at timestamptz,
  deleted_at timestamptz
)
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
    select msg.id, msg.sender_id, msg.body, msg.created_at, msg.deleted_at
    from public.messages msg
    where msg.connection_id = p_connection
    order by msg.created_at desc
    limit greatest(1, least(coalesce(p_limit, 200), 200));
end
$$;

revoke all on function public.get_conversation(uuid, integer) from public, anon;
grant execute on function public.get_conversation(uuid, integer)
  to authenticated, service_role;
