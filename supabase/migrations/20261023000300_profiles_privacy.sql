-- B1: stop anonymous clients from reading profile rows (and therefore emails
-- and admin flags), while keeping signup's "does this email exist?" check and
-- signed-in profile browsing working.

-- Admin checks must not read profiles.is_admin directly once that column is
-- no longer selectable by authenticated users.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin
  );
$$;

revoke all on function public.is_admin() from public;
revoke all on function public.is_admin() from anon;
grant execute on function public.is_admin() to authenticated;

-- Replace the full-row public policy with an authenticated-only read.
drop policy if exists "Allow public email lookup" on public.profiles;

create policy "Authenticated can read profiles"
  on public.profiles
  for select
  to authenticated
  using (true);

revoke select on public.profiles from anon;
revoke select on public.profiles from authenticated;

-- Email and is_admin are deliberately not granted. search_vector is internal.
grant select (
  id,
  first_name,
  last_name,
  display_name,
  bio,
  avatar_url,
  photos,
  role,
  learning_skills,
  teaching_skills,
  learning_styles,
  languages,
  availability,
  skill_categories,
  teaching_skill_images,
  timezone,
  is_profile_completed,
  has_completed_onboarding,
  created_at,
  updated_at
) on public.profiles to authenticated;

-- Signup still needs to know whether an address is already registered, but it
-- must not receive the row.
create or replace function public.email_exists(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where email = lower(btrim(p_email))
  );
$$;

revoke all on function public.email_exists(text) from public;
grant execute on function public.email_exists(text) to anon, authenticated;

-- Policies that used to read profiles.is_admin now use the helper.
drop policy if exists "reports_read" on public.reports;
create policy "reports_read"
  on public.reports
  for select
  to authenticated
  using (reporter_id = auth.uid() or public.is_admin());

drop policy if exists "modlog_admin_read" on public.skill_moderation_log;
create policy "modlog_admin_read"
  on public.skill_moderation_log
  for select
  to authenticated
  using (public.is_admin());
