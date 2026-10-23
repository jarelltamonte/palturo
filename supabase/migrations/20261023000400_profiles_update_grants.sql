-- B2: make the admin flag (and email/id) non-writable by clients, and finish
-- the B1 grant cleanup. Profile creation/deletion are service-role operations.

-- anon needs nothing on this table; email_exists() is SECURITY DEFINER.
revoke all on public.profiles from anon;

-- authenticated keeps only column-scoped SELECT and UPDATE.
revoke all on public.profiles from authenticated;

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

-- Deliberately absent: id, email, is_admin, created_at, search_vector.
grant update (
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
  updated_at
) on public.profiles to authenticated;

-- Idempotent policy definitions (the table now has a single read policy).
drop policy if exists "Authenticated can read profiles" on public.profiles;
create policy "Authenticated can read profiles"
  on public.profiles
  for select
  to authenticated
  using (true);

drop policy if exists "Users can read own profile" on public.profiles;
