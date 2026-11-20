-- Device and OS analytics. A user can have many rows: one per app install.
--
-- The app generates a random device id and stores it locally; no advertising
-- id, hardware serial, or IP is collected.

create table if not exists public.profile_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id text not null,
  platform text not null,
  os text,
  os_version text,
  browser text,
  app_version text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint profile_devices_unique unique (user_id, device_id)
);

create index if not exists profile_devices_user_idx
  on public.profile_devices (user_id, last_seen_at desc);

alter table public.profile_devices enable row level security;
revoke all on public.profile_devices from public, anon, authenticated;

create or replace function public.save_my_device(
  p_device_id text,
  p_platform text,
  p_os text,
  p_os_version text,
  p_browser text,
  p_app_version text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_device text;
  v_platform text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_device := left(btrim(coalesce(p_device_id, '')), 128);
  v_platform := left(btrim(coalesce(p_platform, '')), 40);
  if char_length(v_device) < 8 or v_platform = '' then
    return;
  end if;

  insert into public.profile_devices (
    user_id, device_id, platform, os, os_version, browser, app_version,
    first_seen_at, last_seen_at
  )
  values (
    v_uid,
    v_device,
    lower(v_platform),
    nullif(left(btrim(coalesce(p_os, '')), 80), ''),
    nullif(left(btrim(coalesce(p_os_version, '')), 120), ''),
    nullif(left(btrim(coalesce(p_browser, '')), 80), ''),
    nullif(left(btrim(coalesce(p_app_version, '')), 80), ''),
    now(),
    now()
  )
  on conflict (user_id, device_id) do update
  set platform = excluded.platform,
      os = excluded.os,
      os_version = excluded.os_version,
      browser = excluded.browser,
      app_version = excluded.app_version,
      last_seen_at = now();
end;
$$;

revoke all on function public.save_my_device(text, text, text, text, text, text)
  from public, anon;
grant execute on function public.save_my_device(text, text, text, text, text, text)
  to authenticated;
