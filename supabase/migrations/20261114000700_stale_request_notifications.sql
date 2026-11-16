-- Request notifications outlived their connections: deleting a QA user or a
-- connection left the row behind, so Activity showed ten requests while only
-- two were pending and the badge counted unread ghosts. Remove the stale rows
-- and keep them in step going forward.

delete from public.notifications n
where n.payload ? 'connection_id'
  and not exists (
    select 1 from public.connections c
    where c.id = nullif(n.payload ->> 'connection_id', '')::uuid
  );

delete from public.notifications n
where n.kind = 'connection_request'
  and exists (
    select 1 from public.connections c
    where c.id = nullif(n.payload ->> 'connection_id', '')::uuid
      and c.status <> 'pending'
  );

create or replace function public.cleanup_connection_notifications()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.notifications
    where payload ->> 'connection_id' = old.id::text;
    return old;
  end if;

  if tg_op = 'UPDATE'
     and new.status is distinct from old.status
     and new.status <> 'pending' then
    delete from public.notifications
    where kind = 'connection_request'
      and payload ->> 'connection_id' = new.id::text;
  end if;

  return new;
end;
$$;

drop trigger if exists cleanup_connection_notifications on public.connections;
create trigger cleanup_connection_notifications
  after delete or update of status on public.connections
  for each row execute function public.cleanup_connection_notifications();
