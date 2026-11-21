-- Smoke tests for the card-level matching primitives.
-- Run against a migrated database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/card_pair_score.sql
--
-- These assertions do not need seed users. The integration fixture that proves
-- "web dev mentor does not see a traditional-music learner" lives in
-- card_matching_fixtures.sql.
--
-- Compare with a tolerance: the function returns `real`, and 0.8 is not
-- exactly representable, so real = numeric would fail.

do $$
begin
  -- Exact node.
  assert abs(public.skill_pair_score(
    'web.dev'::extensions.ltree,
    'web.dev'::extensions.ltree
  ) - 1.0) < 0.001, 'exact pair must score 1.0';

  -- Parent -> child.
  assert abs(public.skill_pair_score(
    'web'::extensions.ltree,
    'web.dev'::extensions.ltree
  ) - 0.80) < 0.001, 'ancestor pair must score 0.80';

  -- Child -> parent.
  assert abs(public.skill_pair_score(
    'web.dev'::extensions.ltree,
    'web'::extensions.ltree
  ) - 0.65) < 0.001, 'descendant pair must score 0.65';

  -- Siblings.
  assert abs(public.skill_pair_score(
    'music.traditional'::extensions.ltree,
    'music.theory'::extensions.ltree
  ) - 0.45) < 0.001, 'siblings must score 0.45';

  -- Unrelated.
  assert abs(public.skill_pair_score(
    'web.dev'::extensions.ltree,
    'music.traditional'::extensions.ltree
  )) < 0.001, 'unrelated skills must score 0.0';

  -- The reported failure: unrelated cards never clear the default gate.
  assert public.skill_pair_score(
    'web.dev'::extensions.ltree,
    'music.traditional'::extensions.ltree
  ) < 0.40, 'unrelated pair must be below min_skill_score';
end $$;
