-- The onboarding flag is in the authenticated UPDATE grant, so an empty
-- account could set it directly and become discoverable. Turn it on only when
-- the profile is ready, and turn it back off when the account has no skill for
-- its role (the anti-spam condition discovery relies on). A profile that only
-- lacks availability is left alone: the app's completion rule does not require
-- availability, and flipping those users would send them back to onboarding.
create or replace function public.set_onboarding_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_has_role_skill boolean;
  v_ready boolean;
begin
  v_has_role_skill :=
    new.role is not null
    and exists (
      select 1 from public.user_skills us
      where us.user_id = new.id
        and (
          new.role::text = 'both'
          or (new.role::text = 'mentor' and us.kind = 'teach')
          or (new.role::text = 'learner' and us.kind = 'learn')
        )
    );

  v_ready :=
    v_has_role_skill
    and coalesce(array_length(new.learning_styles, 1), 0) > 0
    and coalesce(array_length(new.languages, 1), 0) > 0
    and (case jsonb_typeof(new.availability)
          when 'array' then jsonb_array_length(new.availability) > 0
          when 'object' then new.availability <> '{}'::jsonb
          else false
        end);

  if v_ready then
    new.has_completed_onboarding := true;
  elsif coalesce(new.has_completed_onboarding, false)
        and not v_has_role_skill then
    new.has_completed_onboarding := false;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_onboarding_completed on public.profiles;
create trigger trg_profiles_onboarding_completed
  before insert or update on public.profiles
  for each row
  execute function public.set_onboarding_completed();
