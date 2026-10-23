-- Align stored completion flags with the single profile-completion rule:
-- avatar + bio + at least one language + at least one learning style +
-- at least one skill for the user's role. Onboarding used to mark users
-- complete without an avatar/bio, so backfill existing rows.
update public.profiles as p
set is_profile_completed = (
  coalesce(nullif(btrim(p.avatar_url), ''), '') <> ''
  and coalesce(btrim(p.bio), '') <> ''
  and coalesce(array_length(p.languages, 1), 0) > 0
  and coalesce(array_length(p.learning_styles, 1), 0) > 0
  and case p.role::text
    when 'mentor' then coalesce(array_length(p.teaching_skills, 1), 0) > 0
    when 'learner' then coalesce(array_length(p.learning_skills, 1), 0) > 0
    else coalesce(array_length(p.teaching_skills, 1), 0) > 0
      or coalesce(array_length(p.learning_skills, 1), 0) > 0
  end
);
