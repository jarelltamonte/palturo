-- "Clear read" for Activity: remove only the caller's already-read rows.
-- Writes stay behind a SECURITY DEFINER RPC; the table remains read-only.

create or replace function public.clear_read_notifications()
returns integer
language sql
security definer
set search_path to 'public'
as $$
  with deleted as (
    delete from public.notifications
    where user_id = auth.uid()
      and read_at is not null
    returning 1
  )
  select count(*)::int from deleted;
$$;

revoke all on function public.clear_read_notifications() from public;
revoke all on function public.clear_read_notifications() from anon;
grant execute on function public.clear_read_notifications() to authenticated;
grant execute on function public.clear_read_notifications() to service_role;
