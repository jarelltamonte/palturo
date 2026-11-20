-- Role follows skills.
--
-- A profile with a teaching skill is a mentor, a profile with a learning skill
-- is a learner, and both means both. Removing the last skill of a kind removes
-- that role; adding one adds it. This keeps profiles.role, browse counts, the
-- showcase gate, and onboarding_ready consistent with user_skills no matter
-- which path writes the arrays.
--
-- The client now sends the derived role too, but the trigger is the guarantee:
-- save_user_skills, admin removals, and direct array repairs all pass through
-- the profiles arrays.

create or replace function public.sync_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_learning boolean := coalesce(array_length(new.learning_skills, 1), 0) > 0;
  v_teaching boolean := coalesce(array_length(new.teaching_skills, 1), 0) > 0;
  v_role text;
begin
  v_role := case
    when v_learning and v_teaching then 'both'
    when v_teaching then 'mentor'
    else 'learner'
  end;

  if new.role is distinct from v_role::public.user_role then
    new.role := v_role::public.user_role;
  end if;

  return new;
end;
$$;

revoke all on function public.sync_profile_role() from public, anon, authenticated;

drop trigger if exists trg_profiles_role_follows_skills on public.profiles;
-- The 00 prefix makes this run before trg_profiles_onboarding_completed, so the
-- completion trigger sees the role implied by the new skill arrays.
drop trigger if exists trg_profiles_00_role_follows_skills on public.profiles;
create trigger trg_profiles_00_role_follows_skills
  before insert or update of learning_skills, teaching_skills on public.profiles
  for each row
  execute function public.sync_profile_role();

-- Backfill rows written before the trigger existed. A profile with no skills
-- falls back to learner (the app treats it as "setup needed" until a skill is
-- added, so the stored value only needs to be a valid role).
update public.profiles
set role = (
  case
    when coalesce(array_length(learning_skills, 1), 0) > 0
      and coalesce(array_length(teaching_skills, 1), 0) > 0 then 'both'
    when coalesce(array_length(teaching_skills, 1), 0) > 0 then 'mentor'
    else 'learner'
  end
)::public.user_role
where role is distinct from (
  case
    when coalesce(array_length(learning_skills, 1), 0) > 0
      and coalesce(array_length(teaching_skills, 1), 0) > 0 then 'both'
    when coalesce(array_length(teaching_skills, 1), 0) > 0 then 'mentor'
    else 'learner'
  end
)::public.user_role;
