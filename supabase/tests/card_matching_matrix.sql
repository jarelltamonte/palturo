-- Full deck matrix + cache freshness for the 20 seeded accounts.
--
--   docker exec -i supabase_db_palturo psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/card_matching_matrix.sql

do $$
declare
  r record;
  v_uid uuid;
  v_n int;
  v_bad int;
begin
  for r in
    select * from (values
      -- viewer, target side, expected cards
      ('marisol.rivera@example.test',   'learner', 3),
      ('marisol.rivera@example.test',   'mentor',  1),
      ('diego.santos@example.test',     'learner', 0),
      ('diego.santos@example.test',     'mentor',  1),
      ('althea.cruz@example.test',      'learner', 1),
      ('althea.cruz@example.test',      'mentor',  1),
      ('rafael.mendoza@example.test',   'learner', 2),
      ('rafael.mendoza@example.test',   'mentor',  1),
      ('lourdes.bautista@example.test', 'learner', 1),
      ('lourdes.bautista@example.test', 'mentor',  1),
      ('emilio.garcia@example.test',    'learner', 1),
      ('emilio.garcia@example.test',    'mentor',  1),
      ('bianca.reyes@example.test',     'learner', 1),
      ('bianca.reyes@example.test',     'mentor',  1),
      ('marco.villanueva@example.test', 'learner', 1),
      ('marco.villanueva@example.test', 'mentor',  1),
      ('carmela.delacruz@example.test', 'learner', 1),
      ('carmela.delacruz@example.test', 'mentor',  1),
      ('nathaniel.ramos@example.test',  'learner', 1),
      ('nathaniel.ramos@example.test',  'mentor',  1),
      ('sofia.aquino@example.test',     'learner', 0),
      ('sofia.aquino@example.test',     'mentor',  1),
      ('gabriel.navarro@example.test',  'learner', 0),
      ('gabriel.navarro@example.test',  'mentor',  1),
      ('isabella.torres@example.test',  'learner', 1),
      ('isabella.torres@example.test',  'mentor',  1),
      ('joaquin.castillo@example.test', 'learner', 1),
      ('joaquin.castillo@example.test', 'mentor',  1),
      ('camille.domingo@example.test',  'learner', 1),
      ('camille.domingo@example.test',  'mentor',  1),
      ('elias.mercado@example.test',    'learner', 1),
      ('elias.mercado@example.test',    'mentor',  1),
      ('teresa.salazar@example.test',   'learner', 1),
      ('teresa.salazar@example.test',   'mentor',  1),
      ('miguel.ferrer@example.test',    'learner', 1),
      ('miguel.ferrer@example.test',    'mentor',  2),
      ('patricia.lim@example.test',     'learner', 1),
      ('patricia.lim@example.test',     'mentor',  1),
      ('andres.velasco@example.test',   'learner', 2),
      ('andres.velasco@example.test',   'mentor',  1)
    ) as t(email, target, expected)
  loop
    select id into v_uid from auth.users where email = r.email;
    perform set_config(
      'request.jwt.claims',
      json_build_object('sub', v_uid, 'role', 'authenticated')::text,
      false
    );

    select count(*) into v_n
    from public.match_cards(
      v_uid, r.target::public.embed_role, 100, 0.50, true, 0.7, 0.3
    );

    if v_n <> r.expected then
      raise exception 'FAIL: % as % expected % cards, got %',
        r.email, r.target, r.expected, v_n;
    end if;

    -- Every row must clear the gate, be someone else, and come from a ready side.
    select count(*) into v_bad
    from public.match_cards(
      v_uid, r.target::public.embed_role, 100, 0.50, true, 0.7, 0.3
    ) mc
    where mc.skill_score < 0.50
       or mc.candidate_id = v_uid
       or not public.side_ready(
            mc.candidate_id,
            case when r.target = 'mentor'
                 then 'teach'::public.skill_kind
                 else 'learn'::public.skill_kind end
          );
    if v_bad > 0 then
      raise exception 'FAIL: % as % has % invalid card(s)', r.email, r.target, v_bad;
    end if;
  end loop;

  raise notice 'PASS: 40-deck matrix';
end $$;

-- Cache freshness: every row must be fresh, not just one.
begin;
do $$
declare
  v_marisol uuid := (select id from auth.users where email = 'marisol.rivera@example.test');
  v_rafael  uuid := (select id from auth.users where email = 'rafael.mendoza@example.test');
  v_rev     int  := (select (value #>> '{}')::int from public.pipeline_config where key = '__revision');
  v_fresh   boolean;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_marisol, 'role', 'authenticated')::text,
    false
  );

  delete from public.match_cache_v2
  where user_id = v_marisol and as_role = 'learner';

  insert into public.match_cache_v2 (
    user_id, as_role, source_card_id, candidate_card_id, candidate_id,
    rank, bi_score, reciprocal_score, calibrated_score, display_name, role,
    skill_name, skill_path, skill_kind, model_name, config_version
  )
  select v_marisol, 'learner', mc.source_card_id, mc.card_id, mc.candidate_id,
         row_number() over (order by mc.bi_score desc),
         mc.bi_score, mc.bi_score, mc.bi_score, '', 'both',
         mc.skill_name, mc.skill_path, mc.skill_kind, 'test', v_rev
  from public.match_cards(v_marisol, 'learner', 100, 0.50, true, 0.7, 0.3) mc;

  select public.cache_is_fresh_v2(v_marisol, 'learner', v_rev) into v_fresh;
  if v_fresh is not true then
    raise exception 'FAIL: freshly written card cache reported stale';
  end if;

  -- One stale candidate card must invalidate the whole deck.
  update public.user_skills
  set updated_at = now() + interval '1 minute'
  where user_id = v_rafael and kind = 'learn';

  select public.cache_is_fresh_v2(v_marisol, 'learner', v_rev) into v_fresh;
  if v_fresh is not false then
    raise exception 'FAIL: one stale row still reported the deck fresh';
  end if;

  raise notice 'PASS: cache freshness';
end $$;
rollback;


