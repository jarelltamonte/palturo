-- Per-item read needs a SECURITY DEFINER RPC: notification tables are not
-- writable by authenticated clients after the 2026-10-23 grant lockdown.

create or replace function public.mark_notification_read(p_id uuid)
returns void
language sql
security definer
set search_path to 'public'
as $$
  update public.notifications
    set read_at = now()
    where id = p_id
      and user_id = auth.uid()
      and read_at is null;
$$;

revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.mark_notification_read(uuid) from anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_notification_read(uuid) to service_role;
