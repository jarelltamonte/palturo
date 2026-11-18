-- Undoing a decline must restore the request's unread badge.
--
-- The decline flow marks the incoming connection_request notification read
-- (and the five-second timer may win the race with Undo). Reopening the
-- connection without restoring the notification leaves the Requests badge one
-- short, so reset it here and recreate it if it was cleared.

create or replace function public.undo_decline_connection(p_connection uuid)
returns table(status text)
language plpgsql
security definer
set search_path to 'public'
as $function$
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

  update public.notifications
  set read_at = null
  where user_id = me
    and kind = 'connection_request'
    and payload->>'connection_id' = p_connection::text;

  if not found then
    perform public.notify(
      me,
      'connection_request',
      jsonb_build_object(
        'connection_id', p_connection,
        'requester_id', c.requester_id
      )
    );
  end if;

  return query select c.status::text;
end;
$function$;

revoke all on function public.undo_decline_connection(uuid) from public, anon;
grant execute on function public.undo_decline_connection(uuid) to authenticated, service_role;
