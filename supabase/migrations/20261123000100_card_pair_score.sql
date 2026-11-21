-- Phase 0 of the card-level matching rework: skill compatibility + gated retrieval.
--
-- The profile-level matcher (as of 20261121000800) already applies side
-- readiness, blocks, connections, reports, and model-aware vectors, but it
-- still unions an arbitrary 200-user fallback with no skill overlap. This
-- migration adds the missing precision layer without changing any existing
-- function:
--   * skill_pair_score() scores two taxonomy paths
--   * match_candidates_v2() retrieves candidates only through a compatible card
--   * config defaults keep the new path off until matcher_mode flips to gated
--
-- Rollback: drop match_candidates_v2 and skill_pair_score; delete the config
-- keys. Nothing existing is replaced.

create or replace function public.skill_pair_score(
  a extensions.ltree,
  b extensions.ltree
) returns real
language sql
immutable
set search_path = public, extensions
as $$
  select case
    when a is null or b is null then 0::real
    when a = b then 1.00::real
    when a @> b then 0.80::real          -- a is an ancestor of b
    when b @> a then 0.65::real          -- a is a descendant of b
    when nlevel(a) > 1 and nlevel(b) > 1
         and subpath(a, 0, nlevel(a) - 1) = subpath(b, 0, nlevel(b) - 1)
      then 0.45::real                    -- siblings
    else 0::real
  end
$$;

revoke all on function public.skill_pair_score(extensions.ltree, extensions.ltree)
  from public, anon;
grant execute on function public.skill_pair_score(extensions.ltree, extensions.ltree)
  to authenticated, service_role;

insert into public.pipeline_config (key, value) values
  ('matcher_mode', '"profile"'::jsonb),
  ('min_skill_score', '0.50'::jsonb),
  ('min_final_score', '0.50'::jsonb),
  ('require_discovery_media', 'true'::jsonb),
  ('max_per_user', '2'::jsonb),
  ('max_per_skill', '3'::jsonb)
on conflict (key) do nothing;

create or replace function public.match_candidates_v2(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real,
  p_min_skill real default 0.50,
  p_require_media boolean default true
) returns table (
  candidate_id uuid,
  bi_score real,
  skill_score real,
  card_id uuid,
  skill_id uuid,
  skill_name text,
  skill_path text,
  skill_kind public.skill_kind
)
language sql
stable
security definer
set search_path = public, extensions
as $$
with seeker as (
  select case when p_target = 'mentor'
              then 'learner'::public.embed_role
              else 'mentor'::public.embed_role end as s_role
),
target_kind as (
  select case when p_target = 'mentor'
              then 'teach'::public.skill_kind
              else 'learn'::public.skill_kind end as k
),
blocked as (
  select blocked_id as uid from public.blocks where blocker_id = p_user
  union
  select blocker_id as uid from public.blocks where blocked_id = p_user
),
connected as (
  select case when c.requester_id = p_user then c.recipient_id else c.requester_id end as uid
  from public.connections c
  where c.status in ('pending', 'accepted') and c.unmatched_at is null
    and (c.requester_id = p_user or c.recipient_id = p_user)
),
reported as (
  select case when r.reporter_id = p_user then r.reported_id else r.reporter_id end as uid
  from public.reports r
  where r.reporter_id = p_user or r.reported_id = p_user
),
model as (
  select coalesce(
    (select value #>> '{}' from public.pipeline_config where key = 'embedding_model'),
    'nvidia/nemotron-3.5-embed-1b'
  ) as name
),
my_cards as (
  select n.path
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  where us.user_id = p_user
    and us.kind = case when p_target = 'mentor'
                       then 'learn'::public.skill_kind
                       else 'teach'::public.skill_kind end
    and n.kind = 'skill'
    and n.status = 'approved'
),
pairs as (
  select c.user_id as candidate_id,
         c.id as card_id,
         c.skill_id,
         n.name as skill_name,
         n.path::text as skill_path,
         c.kind as skill_kind,
         max(public.skill_pair_score(m.path, n.path))::real as skill_score
  from public.user_skills c
  join public.skill_nodes n
    on n.id = c.skill_id
   and n.kind = 'skill'
   and n.status = 'approved'
  join public.profiles p on p.id = c.user_id and p.has_completed_onboarding
  join my_cards m
    on public.skill_pair_score(m.path, n.path) >= p_min_skill
  cross join target_kind tk
  where c.kind = tk.k
    and c.user_id <> p_user
    and public.side_ready(c.user_id, tk.k)
    and (not p_require_media or c.kind <> 'teach'::public.skill_kind)
    and not exists (select 1 from blocked b where b.uid = c.user_id)
    and not exists (select 1 from connected cn where cn.uid = c.user_id)
    and not exists (select 1 from reported rp where rp.uid = c.user_id)
  group by c.user_id, c.id, c.skill_id, n.name, n.path, c.kind
),
s_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query'
    and role = (select s_role from seeker)
    and field_group = 'skills'::public.embed_field_group
    and model_name = (select name from model)
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query'
    and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
    and model_name = (select name from model)
),
s_sc as (
  select e.user_id,
         (1 - extensions.cosine_distance(s_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join s_me
  where e.role = p_target
    and e.input_type = 'passage'
    and e.field_group = 'skills'::public.embed_field_group
    and e.model_name = (select name from model)
    and e.user_id <> p_user
),
c_sc as (
  select e.user_id,
         (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target
    and e.input_type = 'passage'
    and e.field_group = 'context'::public.embed_field_group
    and e.model_name = (select name from model)
    and e.user_id <> p_user
),
best as (
  select distinct on (p.candidate_id)
    p.candidate_id, p.card_id, p.skill_id, p.skill_name, p.skill_path,
    p.skill_kind, p.skill_score
  from pairs p
  order by p.candidate_id, p.skill_score desc, p.skill_path
)
select b.candidate_id,
       (p_w_skills * coalesce(s_sc.sim, 0)
        + p_w_context * coalesce(c_sc.sim, 0))::real as bi_score,
       b.skill_score,
       b.card_id,
       b.skill_id,
       b.skill_name,
       b.skill_path,
       b.skill_kind
from best b
left join s_sc on s_sc.user_id = b.candidate_id
left join c_sc on c_sc.user_id = b.candidate_id
where coalesce(auth.role(), '') = 'service_role' or p_user = auth.uid()
order by 2 desc
limit p_limit;
$$;

revoke all on function public.match_candidates_v2(
  uuid, public.embed_role, integer, real, real, real, boolean
) from public, anon;
grant execute on function public.match_candidates_v2(
  uuid, public.embed_role, integer, real, real, real, boolean
) to authenticated, service_role;

