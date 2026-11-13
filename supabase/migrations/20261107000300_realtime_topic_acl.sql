-- Enforce chat and notification Realtime topic membership on the server.
--
-- The client joins chat/notification topics with `private: true`. Server-side
-- enforcement also requires the project setting "Allow public access" to be
-- disabled in Supabase Realtime settings; with it enabled, a modified client
-- can still use a public topic. See supabase/README.md.
--
-- Do not ALTER TABLE realtime.messages: RLS is already enabled and the
-- migration role is not the table owner.

create or replace function public.chat_topic_allowed(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.connections c
    where p_topic = 'chat:' || c.id::text
      and c.status = 'accepted'
      and (c.requester_id = auth.uid() or c.recipient_id = auth.uid())
      and not public.blocked_between(
        auth.uid(),
        case when c.requester_id = auth.uid() then c.recipient_id else c.requester_id end
      )
  );
$$;

revoke all on function public.chat_topic_allowed(text) from public, anon;
grant execute on function public.chat_topic_allowed(text) to authenticated;

drop policy if exists "chat participants can read their topic" on realtime.messages;
create policy "chat participants can read their topic"
  on realtime.messages
  for select
  to authenticated
  using (
    realtime.messages.extension in ('broadcast', 'presence')
    and public.chat_topic_allowed(realtime.topic())
  );

drop policy if exists "chat participants can write their topic" on realtime.messages;
create policy "chat participants can write their topic"
  on realtime.messages
  for insert
  to authenticated
  with check (
    realtime.messages.extension in ('broadcast', 'presence')
    and public.chat_topic_allowed(realtime.topic())
  );

drop policy if exists "users can read their notification topic" on realtime.messages;
create policy "users can read their notification topic"
  on realtime.messages
  for select
  to authenticated
  using (realtime.topic() = 'notifications:' || auth.uid()::text);

-- The message stream and global chat-state listener are private channels with
-- Postgres Changes. They need a join policy, but row visibility stays governed
-- by the messages RLS policy.
drop policy if exists "authenticated can join message streams" on realtime.messages;
create policy "authenticated can join message streams"
  on realtime.messages
  for select
  to authenticated
  using (realtime.topic() like 'public:messages:%');

drop policy if exists "authenticated can join chat state" on realtime.messages;
create policy "authenticated can join chat state"
  on realtime.messages
  for select
  to authenticated
  using (realtime.topic() = 'chat_state_global_messages');

-- Postgres Changes only fires for tables in the supabase_realtime publication.
-- Guarded so the migration can be re-run safely.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end
$$;
