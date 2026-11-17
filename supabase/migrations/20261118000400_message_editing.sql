-- Message editing + live presence.
--
-- messages gain edited_at; only the sender can edit, and only while the
-- message is not deleted. get_conversation returns the new column so both
-- participants can tag the bubble as edited.
--
-- profiles joins the realtime publication so peers' last_seen_at changes are
-- pushed instead of polled.

alter table public.messages
  add column if not exists edited_at timestamp with time zone;

drop function if exists public.get_conversation(uuid, integer);

create function public.get_conversation(p_connection uuid, p_limit integer default 200)
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
    select msg.id, msg.sender_id, msg.body, msg.created_at, msg.deleted_at, msg.edited_at
    from public.messages msg
    where msg.connection_id = p_connection
    order by msg.created_at desc
    limit greatest(1, least(coalesce(p_limit, 200), 200));
end
$function$;

revoke all on function public.get_conversation(uuid, integer) from public, anon;
grant execute on function public.get_conversation(uuid, integer) to authenticated, service_role;

create or replace function public.edit_message(p_message uuid, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  me uuid := auth.uid();
  m public.messages%rowtype;
  c public.connections%rowtype;
  v_body text := btrim(coalesce(p_body, ''));
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  if p_message is null then
    raise exception 'Message is required';
  end if;
  if v_body = '' then
    raise exception 'Message cannot be empty';
  end if;
  if length(v_body) > 4000 then
    raise exception 'Message is too long';
  end if;

  select * into m from public.messages where id = p_message;
  if not found then
    raise exception 'Message not found';
  end if;
  if m.sender_id <> me then
    raise exception 'Only the sender can edit this message';
  end if;
  if m.deleted_at is not null then
    raise exception 'Deleted messages cannot be edited';
  end if;

  select * into c from public.connections where id = m.connection_id;
  if not found or c.status <> 'accepted' then
    raise exception 'Chat is not available';
  end if;

  -- Saving the unchanged text is not an edit.
  if v_body = m.body then
    return jsonb_build_object(
      'id', m.id,
      'body', m.body,
      'edited_at', m.edited_at
    );
  end if;

  update public.messages
    set body = v_body,
        edited_at = now()
    where id = p_message
    returning * into m;

  return jsonb_build_object(
    'id', m.id,
    'body', m.body,
    'edited_at', m.edited_at
  );
end
$function$;

revoke all on function public.edit_message(uuid, text) from public, anon;
grant execute on function public.edit_message(uuid, text) to authenticated, service_role;

-- Presence: stream last_seen_at updates to signed-in clients (RLS still
-- limits delivery to visible profiles).
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end
$$;
