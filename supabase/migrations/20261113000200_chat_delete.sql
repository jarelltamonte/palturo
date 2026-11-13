-- Chat deletion: a sender can remove one message, and either participant can
-- clear a conversation's messages while keeping the Pal connection.

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
    -- Idempotent: a retry after a successful delete is a no-op.
    return;
  end if;
  if m.sender_id <> me then
    raise exception 'Only the sender can delete this message';
  end if;

  delete from public.messages where id = p_message;
end;
$$;

revoke all on function public.delete_message(uuid) from public, anon;
grant execute on function public.delete_message(uuid) to authenticated, service_role;

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
    -- Idempotent: the conversation may already be gone.
    return;
  end if;
  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;

  delete from public.messages where connection_id = p_connection;
  update public.connections
    set requester_read_at = now(), recipient_read_at = now()
    where id = p_connection;
end;
$$;

revoke all on function public.delete_conversation(uuid) from public, anon;
grant execute on function public.delete_conversation(uuid) to authenticated, service_role;
