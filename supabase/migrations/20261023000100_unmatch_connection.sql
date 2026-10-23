-- Unmatch: delete a connection the caller participates in.
-- Deleting the connection cascades messages, feedback and any other rows that
-- reference it, so both sides lose the thread as expected.

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
    -- Idempotent: a retry after a successful unmatch is a no-op.
    return;
  end if;

  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;

  if c.status <> 'accepted' then
    raise exception 'Only accepted connections can be unmatched';
  end if;

  delete from public.connections where id = p_connection;
end;
$$;

revoke all on function public.unmatch_connection(uuid) from public;
revoke all on function public.unmatch_connection(uuid) from anon;
grant execute on function public.unmatch_connection(uuid) to authenticated;
