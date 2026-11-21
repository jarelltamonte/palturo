-- Integration assertions for the card-level matcher against the 20 seeded accounts.
--
-- Run after seed_local_accounts.sql:
--   docker exec -i supabase_db_palturo psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/card_matching_fixtures.sql
--
-- The functions are security definer and check auth.uid(), so each scenario
-- sets request.jwt.claims before calling them.

do $$
declare
  v_marisol uuid := (select id from auth.users where email = 'marisol.rivera@example.test');
  v_diego   uuid := (select id from auth.users where email = 'diego.santos@example.test');
  v_althea  uuid := (select id from auth.users where email = 'althea.cruz@example.test');
  v_sofia   uuid := (select id from auth.users where email = 'sofia.aquino@example.test');
  v_lourdes uuid := (select id from auth.users where email = 'lourdes.bautista@example.test');
  v_miguel  uuid := (select id from auth.users where email = 'miguel.ferrer@example.test');
  v_andres  uuid := (select id from auth.users where email = 'andres.velasco@example.test');
  v_emilio  uuid := (select id from auth.users where email = 'emilio.garcia@example.test');
  v_rafael  uuid := (select id from auth.users where email = 'rafael.mendoza@example.test');
  v_count int;
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_marisol, 'role', 'authenticated')::text,
    false
  );

  -- The reported failure: Diego wants Traditional Music, Marisol teaches Web
  -- Development. He must never enter her learner deck.
  if exists (
    select 1 from public.match_cards(v_marisol, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_diego
  ) then
    raise exception 'FAIL: Traditional Music learner leaked into the Web Development mentor deck';
  end if;

  if exists (
    select 1 from public.match_candidates_v2(v_marisol, 'learner', 100, 0.7, 0.3, 0.50, true)
    where candidate_id = v_diego
  ) then
    raise exception 'FAIL: gated retrieval leaked the unrelated learner';
  end if;

  -- Exact overlap must survive the gate.
  if not exists (
    select 1 from public.match_cards(v_marisol, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_lourdes and skill_score >= 0.99
  ) then
    raise exception 'FAIL: exact Web Development learner (Lourdes) missing';
  end if;
  if not exists (
    select 1 from public.match_cards(v_marisol, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_rafael
  ) then
    raise exception 'FAIL: Web Development learner (Rafael) missing';
  end if;

  -- Reciprocal mentor view: Lourdes teaches the cooking Marisol wants.
  if not exists (
    select 1 from public.match_cards(v_marisol, 'mentor', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_lourdes and skill_score >= 0.99
  ) then
    raise exception 'FAIL: cooking mentor (Lourdes) missing for Marisol';
  end if;

  -- Paused card: Marisol paused Woodworking, so Miguel must not appear even
  -- though he teaches it.
  if exists (
    select 1 from public.match_cards(v_marisol, 'mentor', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_miguel
  ) then
    raise exception 'FAIL: paused Woodworking card still matched Miguel';
  end if;

  -- The other half of the reported pair: Andres teaches Traditional Music, so
  -- Diego and Emilio must appear for him.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_andres, 'role', 'authenticated')::text,
    false
  );
  if not exists (
    select 1 from public.match_cards(v_andres, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_diego
  ) then
    raise exception 'FAIL: Traditional Music learner (Diego) missing for Andres';
  end if;
  if not exists (
    select 1 from public.match_cards(v_andres, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_emilio
  ) then
    raise exception 'FAIL: Traditional Music learner (Emilio) missing for Andres';
  end if;
  if exists (
    select 1 from public.match_cards(v_andres, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_sofia
  ) then
    raise exception 'FAIL: unrelated Python learner leaked into the music deck';
  end if;

  -- Diego looking for mentors: Andres (teaches music) yes, Marisol (web) no.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_diego, 'role', 'authenticated')::text,
    false
  );
  if not exists (
    select 1 from public.match_cards(v_diego, 'mentor', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_andres
  ) then
    raise exception 'FAIL: music mentor (Andres) missing for Diego';
  end if;
  if exists (
    select 1 from public.match_cards(v_diego, 'mentor', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_marisol
  ) then
    raise exception 'FAIL: web mentor leaked into the music learner deck';
  end if;

  -- Every returned pair must clear the skill gate.
  select count(*) into v_count
  from public.match_cards(v_diego, 'mentor', 100, 0.50, true, 0.7, 0.3)
  where skill_score < 0.50;
  if v_count > 0 then
    raise exception 'FAIL: % pair(s) below min_skill_score', v_count;
  end if;

  -- Althea (Python) and Sofia (learns Python) are an exact pair.
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_sofia, 'role', 'authenticated')::text,
    false
  );
  if not exists (
    select 1 from public.match_cards(v_sofia, 'mentor', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_althea and skill_score >= 0.99
  ) then
    raise exception 'FAIL: exact Python mentor (Althea) missing for Sofia';
  end if;

  raise notice 'PASS: card matching fixtures';
end $$;

-- Connections must remove a pair.
begin;
do $$
declare
  v_marisol uuid := (select id from auth.users where email = 'marisol.rivera@example.test');
  v_lourdes uuid := (select id from auth.users where email = 'lourdes.bautista@example.test');
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_marisol, 'role', 'authenticated')::text,
    false
  );
  insert into public.connections (requester_id, recipient_id)
  values (v_marisol, v_lourdes);
  if exists (
    select 1 from public.match_cards(v_marisol, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_lourdes
  ) then
    raise exception 'FAIL: existing connection still appears in the deck';
  end if;
  raise notice 'PASS: connection exclusion';
end $$;
rollback;

-- An unapproved note hides that side.
begin;
do $$
declare
  v_andres uuid := (select id from auth.users where email = 'andres.velasco@example.test');
  v_diego  uuid := (select id from auth.users where email = 'diego.santos@example.test');
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_andres, 'role', 'authenticated')::text,
    false
  );
  update public.user_skills
  set note_approved = false
  where user_id = v_diego and kind = 'learn';

  if public.side_ready(v_diego, 'learn'::public.skill_kind) then
    raise exception 'FAIL: unapproved note still leaves the learner side ready';
  end if;
  if exists (
    select 1 from public.match_cards(v_andres, 'learner', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_diego
  ) then
    raise exception 'FAIL: learner with an unapproved note still matched';
  end if;
  raise notice 'PASS: note readiness gate';
end $$;
rollback;

-- Removing the mentor showcase hides the teaching side.
begin;
do $$
declare
  v_andres uuid := (select id from auth.users where email = 'andres.velasco@example.test');
  v_diego  uuid := (select id from auth.users where email = 'diego.santos@example.test');
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_diego, 'role', 'authenticated')::text,
    false
  );
  delete from public.skill_showcases where user_id = v_andres;

  if public.side_ready(v_andres, 'teach'::public.skill_kind) then
    raise exception 'FAIL: mentor side still ready without a showcase';
  end if;
  if exists (
    select 1 from public.match_cards(v_diego, 'mentor', 100, 0.50, true, 0.7, 0.3)
    where candidate_id = v_andres
  ) then
    raise exception 'FAIL: showcase-less mentor still matched';
  end if;
  raise notice 'PASS: showcase readiness gate';
end $$;
rollback;

