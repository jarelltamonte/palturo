-- Admin-visible moderation state on profiles.
alter table public.profiles
  add column if not exists moderation_status text not null default 'active'
    check (moderation_status in ('active', 'suspended', 'banned')),
  add column if not exists suspended_at timestamp with time zone;

create index if not exists profiles_moderation_status_idx
  on public.profiles (moderation_status, created_at desc);
