-- Realtime notifications power the in-app banner and badge without polling.
-- Guarded so the migration can be re-run safely.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;

-- Realtime evaluates Postgres Changes as the subscribing client's role.
-- The 2026-10-23 lockdown removed table access; restore read-only access.
-- The existing notif_read policy still limits rows to user_id = auth.uid().
grant select on public.notifications to authenticated;
