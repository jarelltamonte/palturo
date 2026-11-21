-- Exhaustive serving audit: every viewer, both directions, exact candidate set.
--
-- Expected sets are hardcoded from the seed (independent of the matching SQL),
-- so this catches both missing and extra cards.
--
--   docker exec -i supabase_db_palturo psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/card_serving_audit.sql

begin;

create temp table audit (
  viewer text,
  target text,
  expected int,
  actual int,
  missing int,
  extra int,
  status text
) on commit drop;

create temp table expected (
  viewer text,
  target text,
  candidate text,
  path text,
  kind text
) on commit drop;

insert into expected (viewer, target, candidate, path, kind) values
  ('marisol.rivera@example.test', 'learner', 'rafael.mendoza@example.test', 'modern_practical_skills.programming.web_development', 'learn'),
  ('marisol.rivera@example.test', 'learner', 'lourdes.bautista@example.test', 'modern_practical_skills.programming.web_development', 'learn'),
  ('marisol.rivera@example.test', 'learner', 'gabriel.navarro@example.test', 'modern_practical_skills.programming.web_development', 'learn'),
  ('marisol.rivera@example.test', 'mentor',  'lourdes.bautista@example.test', 'cooking_culinary.filipino_cooking', 'teach'),

  ('diego.santos@example.test', 'mentor', 'andres.velasco@example.test', 'performing_arts.traditional_music', 'teach'),

  ('althea.cruz@example.test', 'learner', 'sofia.aquino@example.test', 'modern_practical_skills.programming.python_programming', 'learn'),
  ('althea.cruz@example.test', 'mentor',  'rafael.mendoza@example.test', 'modern_practical_skills.graphic_design', 'teach'),

  ('rafael.mendoza@example.test', 'learner', 'althea.cruz@example.test', 'modern_practical_skills.graphic_design', 'learn'),
  ('rafael.mendoza@example.test', 'learner', 'isabella.torres@example.test', 'modern_practical_skills.graphic_design', 'learn'),
  ('rafael.mendoza@example.test', 'mentor',  'marisol.rivera@example.test', 'modern_practical_skills.programming.web_development', 'teach'),

  ('lourdes.bautista@example.test', 'learner', 'marisol.rivera@example.test', 'cooking_culinary.filipino_cooking', 'learn'),
  ('lourdes.bautista@example.test', 'mentor',  'marisol.rivera@example.test', 'modern_practical_skills.programming.web_development', 'teach'),

  ('emilio.garcia@example.test', 'learner', 'andres.velasco@example.test', 'language_writing.calligraphy', 'learn'),
  ('emilio.garcia@example.test', 'mentor',  'andres.velasco@example.test', 'performing_arts.traditional_music', 'teach'),

  ('bianca.reyes@example.test', 'learner', 'marco.villanueva@example.test', 'performing_arts.folk_dance', 'learn'),
  ('bianca.reyes@example.test', 'mentor',  'marco.villanueva@example.test', 'performing_arts.vocal_music', 'teach'),

  ('marco.villanueva@example.test', 'learner', 'bianca.reyes@example.test', 'performing_arts.vocal_music', 'learn'),
  ('marco.villanueva@example.test', 'mentor',  'bianca.reyes@example.test', 'performing_arts.folk_dance', 'teach'),

  ('carmela.delacruz@example.test', 'learner', 'nathaniel.ramos@example.test', 'modern_practical_skills.sewing', 'learn'),
  ('carmela.delacruz@example.test', 'mentor',  'nathaniel.ramos@example.test', 'traditional_crafts.philippine_handweaving', 'teach'),

  ('nathaniel.ramos@example.test', 'learner', 'carmela.delacruz@example.test', 'traditional_crafts.philippine_handweaving', 'learn'),
  ('nathaniel.ramos@example.test', 'mentor',  'carmela.delacruz@example.test', 'modern_practical_skills.sewing', 'teach'),

  ('sofia.aquino@example.test', 'mentor', 'althea.cruz@example.test', 'modern_practical_skills.programming.python_programming', 'teach'),

  ('gabriel.navarro@example.test', 'mentor', 'marisol.rivera@example.test', 'modern_practical_skills.programming.web_development', 'teach'),

  ('isabella.torres@example.test', 'learner', 'miguel.ferrer@example.test', 'modern_practical_skills.tshirt_printing', 'learn'),
  ('isabella.torres@example.test', 'mentor',  'rafael.mendoza@example.test', 'modern_practical_skills.graphic_design', 'teach'),

  ('joaquin.castillo@example.test', 'learner', 'camille.domingo@example.test', 'traditional_crafts.filipino_embroidery', 'learn'),
  ('joaquin.castillo@example.test', 'mentor',  'camille.domingo@example.test', 'traditional_crafts.costume_making', 'teach'),

  ('camille.domingo@example.test', 'learner', 'joaquin.castillo@example.test', 'traditional_crafts.costume_making', 'learn'),
  ('camille.domingo@example.test', 'mentor',  'joaquin.castillo@example.test', 'traditional_crafts.filipino_embroidery', 'teach'),

  ('elias.mercado@example.test', 'learner', 'teresa.salazar@example.test', 'modern_practical_skills.motorcycle_maintenance', 'learn'),
  ('elias.mercado@example.test', 'mentor',  'teresa.salazar@example.test', 'agriculture_livelihood.farming', 'teach'),

  ('teresa.salazar@example.test', 'learner', 'elias.mercado@example.test', 'agriculture_livelihood.farming', 'learn'),
  ('teresa.salazar@example.test', 'mentor',  'elias.mercado@example.test', 'modern_practical_skills.motorcycle_maintenance', 'teach'),

  ('miguel.ferrer@example.test', 'learner', 'patricia.lim@example.test', 'modern_practical_skills.woodworking', 'learn'),
  ('miguel.ferrer@example.test', 'mentor',  'isabella.torres@example.test', 'modern_practical_skills.tshirt_printing', 'teach'),
  ('miguel.ferrer@example.test', 'mentor',  'patricia.lim@example.test', 'modern_practical_skills.tshirt_printing', 'teach'),

  ('patricia.lim@example.test', 'learner', 'miguel.ferrer@example.test', 'modern_practical_skills.tshirt_printing', 'learn'),
  ('patricia.lim@example.test', 'mentor',  'miguel.ferrer@example.test', 'modern_practical_skills.woodworking', 'teach'),

  ('andres.velasco@example.test', 'learner', 'diego.santos@example.test', 'performing_arts.traditional_music', 'learn'),
  ('andres.velasco@example.test', 'learner', 'emilio.garcia@example.test', 'performing_arts.traditional_music', 'learn'),
  ('andres.velasco@example.test', 'mentor',  'emilio.garcia@example.test', 'language_writing.calligraphy', 'teach');

create temp table actual (
  candidate text,
  path text,
  kind text
) on commit drop;

do $$
declare
  r record;
  v_uid uuid;
  v_min real := coalesce((select (value #>> '{}')::real from public.pipeline_config where key = 'min_skill_score'), 0.5);
  v_media boolean := coalesce((select (value #>> '{}')::boolean from public.pipeline_config where key = 'require_discovery_media'), true);
  v_w record;
  v_expected int;
  v_actual int;
  v_missing int;
  v_extra int;
begin
  select (value ->> 'skills')::real as skills,
         (value ->> 'context')::real as context
    into v_w
  from public.pipeline_config
  where key = 'embedding_weights';

  -- every seeded account, both directions (40 decks, including empty ones)
  for r in
    select u.email as viewer, t.target
    from auth.users u
    cross join (values ('learner'), ('mentor')) as t(target)
    where u.email like '%@example.test'
    order by u.email, t.target
  loop
    select id into v_uid from auth.users where email = r.viewer;
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_uid, 'role', 'authenticated')::text,
      false
    );

    truncate actual;
    insert into actual (candidate, path, kind)
    select cand.email, mc.skill_path, mc.skill_kind::text
    from public.match_cards(
      v_uid,
      r.target::public.embed_role,
      100,
      v_min,
      v_media,
      coalesce(v_w.skills, 0.7),
      coalesce(v_w.context, 0.3)
    ) mc
    join auth.users cand on cand.id = mc.candidate_id;

    select count(*) into v_expected
    from expected e
    where e.viewer = r.viewer and e.target = r.target;

    select count(*) into v_actual from actual;

    select count(*) into v_missing
    from (
      select candidate, path, kind from expected
      where viewer = r.viewer and target = r.target
      except
      select candidate, path, kind from actual
    ) x;

    select count(*) into v_extra
    from (
      select candidate, path, kind from actual
      except
      select candidate, path, kind from expected
      where viewer = r.viewer and target = r.target
    ) x;

    insert into audit (viewer, target, expected, actual, missing, extra, status)
    values (
      r.viewer,
      r.target,
      v_expected,
      v_actual,
      v_missing,
      v_extra,
      case when v_missing = 0 and v_extra = 0 then 'PASS' else 'FAIL' end
    );

    if v_missing <> 0 or v_extra <> 0 then
      raise exception 'FAIL: % as % expected %, actual %, missing %, extra %',
        r.viewer, r.target, v_expected, v_actual, v_missing, v_extra;
    end if;
  end loop;

  if exists (select 1 from audit where status <> 'PASS') then
    raise exception 'FAIL: at least one deck is inaccurate';
  end if;

  raise notice 'PASS: 40/40 decks match the expected candidate sets exactly';
end $$;

select viewer, target, expected, actual, missing, extra, status
from audit
order by viewer, target;

rollback;
