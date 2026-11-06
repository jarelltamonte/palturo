-- A declined request is reversible briefly, but the reopen must be a real
-- server transition. A client-only animation cannot restore the request.

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

  update public.connections
  set status = 'pending',
      responded_at = null,
      recipient_read_at = now()
  where id = p_connection
  returning * into c;

  -- Remove the decline notification so the requester does not see a stale
  -- "declined" event after the request is restored.
  delete from public.notifications
  where user_id = c.requester_id
    and kind = 'request_declined'
    and payload->>'connection_id' = p_connection::text;

  return query select c.status::text;
end;
$$;

revoke all on function public.undo_decline_connection(uuid) from public, anon;
grant execute on function public.undo_decline_connection(uuid)
  to authenticated, service_role;
