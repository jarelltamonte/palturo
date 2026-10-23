-- B15: make the feedback gate usable by participants without exposing a
-- connection-wide probe. `check_feedback_gate` keeps its notification behavior
-- but now ignores callers who are not in the connection.
create or replace function public.check_feedback_gate(p_connection uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  a uuid;
  b uuid;
  me uuid := auth.uid();
begin
  if me is null then
    return;
  end if;
  if not exists (
    select 1 from public.connections c
    where c.id = p_connection
      and (c.requester_id = me or c.recipient_id = me)
  ) then
    return;
  end if;
  if (select count(*) from public.notifications n2
      where n2.kind = 'feedback_ready'
        and (n2.payload->>'connection_id')::uuid = p_connection) >= 1 then
    return;
  end if;
  select count(*) into n from public.messages m where m.connection_id = p_connection;
  if n >= 15 then
    select requester_id, recipient_id into a, b
    from public.connections where id = p_connection;
    perform public.notify(a, 'feedback_ready', jsonb_build_object('connection_id', p_connection));
    perform public.notify(b, 'feedback_ready', jsonb_build_object('connection_id', p_connection));
  end if;
end;
$$;

create or replace function public.my_feedback_status(p_connection uuid)
returns table (gate_open boolean, already_rated boolean)
language sql
stable
security definer
set search_path = public
as $$
  select
    public.feedback_gate_open(p_connection),
    exists (
      select 1 from public.feedback f
      where f.connection_id = p_connection and f.rater_id = auth.uid()
    )
  where exists (
    select 1 from public.connections c
    where c.id = p_connection
      and (c.requester_id = auth.uid() or c.recipient_id = auth.uid())
  );
$$;

revoke all on function public.check_feedback_gate(uuid) from public, anon;
revoke all on function public.my_feedback_status(uuid) from public, anon;
grant execute on function public.check_feedback_gate(uuid) to authenticated;
grant execute on function public.my_feedback_status(uuid) to authenticated;
