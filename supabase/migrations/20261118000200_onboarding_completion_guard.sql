-- Onboarding completion must be derived from the profile data, not only from
-- whatever the client happened to send.
--
-- Two real paths left users stuck in an onboarding loop:
--   1. The profile editor can fill role, skills, styles, languages, and
--      availability without ever writing has_completed_onboarding.
--   2. A profile update that silently matches zero rows (or an older client)
--      leaves the flag false even though the data is complete.
-- AuthGate reads has_completed_onboarding, so those users were sent back to
-- onboarding on every launch.
--
-- This migration makes the flag self-healing: a profile that satisfies the
-- onboarding rule is marked complete by a trigger, existing rows are
-- backfilled, and complete_onboarding() gives the client a server-side
-- fallback when its own write did not stick.

create or replace function public.onboarding_ready(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_user
      and p.role is not null
      and coalesce(array_length(p.learning_styles, 1), 0) > 0
      and coalesce(array_length(p.languages, 1), 0) > 0
      and (case jsonb_typeof(p.availability)
            when 'array' then jsonb_array_length(p.availability) > 0
            when 'object' then p.availability <> '{}'::jsonb
            else false
          end)
      and (
        (p.role::text = 'mentor' and exists (
          select 1 from public.user_skills us
          where us.user_id = p.id and us.kind = 'teach'
        ))
        or (p.role::text = 'learner' and exists (
          select 1 from public.user_skills us
          where us.user_id = p.id and us.kind = 'learn'
        ))
        or (p.role::text = 'both' and exists (
          select 1 from public.user_skills us where us.user_id = p.id
        ))
      )
  );
$$;

revoke all on function public.onboarding_ready(uuid) from public, anon, authenticated;
grant execute on function public.onboarding_ready(uuid) to service_role;

-- The trigger only ever turns the flag on. Clearing it stays an explicit
-- client decision (for example, a future "restart onboarding" action).
create or replace function public.set_onboarding_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not coalesce(new.has_completed_onboarding, false)
     and new.role is not null
     and coalesce(array_length(new.learning_styles, 1), 0) > 0
     and coalesce(array_length(new.languages, 1), 0) > 0
     and (case jsonb_typeof(new.availability)
           when 'array' then jsonb_array_length(new.availability) > 0
           when 'object' then new.availability <> '{}'::jsonb
           else false
         end)
     and exists (
       select 1 from public.user_skills us
       where us.user_id = new.id
         and (
           new.role::text = 'both'
           or (new.role::text = 'mentor' and us.kind = 'teach')
           or (new.role::text = 'learner' and us.kind = 'learn')
         )
     )
  then
    new.has_completed_onboarding := true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_onboarding_completed on public.profiles;
create trigger trg_profiles_onboarding_completed
  before insert or update on public.profiles
  for each row
  execute function public.set_onboarding_completed();

-- Client fallback: let the server decide, so a silent zero-row update cannot
-- leave the user bouncing between onboarding and the app.
create or replace function public.complete_onboarding()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not public.onboarding_ready(v_uid) then
    return false;
  end if;

  update public.profiles
  set has_completed_onboarding = true,
      updated_at = now()
  where id = v_uid
    and not has_completed_onboarding;

  return true;
end;
$$;

revoke all on function public.complete_onboarding() from public, anon;
grant execute on function public.complete_onboarding() to authenticated, service_role;

-- Backfill anyone who already has complete onboarding data but never got the
-- flag (for example, profiles finished through the profile editor).
update public.profiles p
set has_completed_onboarding = true
where not p.has_completed_onboarding
  and public.onboarding_ready(p.id);
