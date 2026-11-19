-- D4: completion asks for the style that matches the role.
-- Learners need a learning style; mentors need a teaching style; both need
-- both. The old rule required a learning style from everyone.
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
      and (
        (p.role::text = 'learner'
          and coalesce(array_length(p.learning_styles, 1), 0) > 0)
        or (p.role::text = 'mentor'
          and coalesce(array_length(p.teaching_styles, 1), 0) > 0)
        or (p.role::text = 'both'
          and coalesce(array_length(p.learning_styles, 1), 0) > 0
          and coalesce(array_length(p.teaching_styles, 1), 0) > 0)
      )
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

revoke all on function public.onboarding_ready(uuid)
  from public, anon, authenticated;
grant execute on function public.onboarding_ready(uuid) to service_role;

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
    and (
      (new.role::text = 'learner'
        and coalesce(array_length(new.learning_styles, 1), 0) > 0)
      or (new.role::text = 'mentor'
        and coalesce(array_length(new.teaching_styles, 1), 0) > 0)
      or (new.role::text = 'both'
        and coalesce(array_length(new.learning_styles, 1), 0) > 0
        and coalesce(array_length(new.teaching_styles, 1), 0) > 0)
    )
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
