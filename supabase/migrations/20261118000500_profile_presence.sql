-- Realtime presence for the Chats list.
--
-- profiles.last_seen_at is not readable by clients (column-scoped grants), so
-- realtime updates for profiles arrive without the timestamp. This table
-- carries just the presence fields, keeps the same privacy rule (the owner's
-- "show my status" switch), and is published so peers see changes instantly.

create table if not exists public.profile_presence (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_seen_at timestamp with time zone not null default now(),
  presence_enabled boolean not null default true
);

alter table public.profile_presence enable row level security;

drop policy if exists "Authenticated can read visible presence" on public.profile_presence;
create policy "Authenticated can read visible presence"
  on public.profile_presence
  for select
  to authenticated
  using (presence_enabled and public.profile_visible(user_id));

revoke all on public.profile_presence from anon;
grant select on public.profile_presence to authenticated;
grant all on public.profile_presence to service_role;

create or replace function public.sync_profile_presence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profile_presence (user_id, last_seen_at, presence_enabled)
  values (
    new.id,
    coalesce(new.last_seen_at, now()),
    coalesce(new.presence_enabled, true)
  )
  on conflict (user_id) do update
    set last_seen_at = excluded.last_seen_at,
        presence_enabled = excluded.presence_enabled;
  return new;
end;
$$;

drop trigger if exists trg_profiles_presence on public.profiles;
create trigger trg_profiles_presence
  after insert or update of last_seen_at, presence_enabled on public.profiles
  for each row
  execute function public.sync_profile_presence();

insert into public.profile_presence (user_id, last_seen_at, presence_enabled)
select id, coalesce(last_seen_at, now()), coalesce(presence_enabled, true)
from public.profiles
on conflict (user_id) do update
  set last_seen_at = excluded.last_seen_at,
      presence_enabled = excluded.presence_enabled;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profile_presence'
  ) then
    alter publication supabase_realtime add table public.profile_presence;
  end if;

  -- The profiles table no longer needs to stream: last_seen_at is filtered
  -- out of those payloads and the presence table carries the real signal.
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime drop table public.profiles;
  end if;
end
$$;
