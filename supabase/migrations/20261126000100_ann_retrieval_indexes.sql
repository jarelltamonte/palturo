-- Retrieval indexes for the two unindexed scans behind matching.
--
-- 1. possible_match_recipients ordered every profile's skills vector by
--    distance with no ANN index, so each profile edit that enqueued a job paid
--    a full scan of profile_embeddings (4 rows per user, 1024 dims each). The
--    query shape is fixed: input_type='query', field_group='skills', and one
--    role per direction, so partial HNSW indexes cover it exactly.
--
-- 2. match_cards resolved context similarity with a cross join over every
--    context passage in the platform, on every deck build. Context is only
--    consumed for cards that already passed the skill gate, so it is resolved
--    per surviving candidate instead. Same values, cost proportional to the
--    gated set rather than to the user count.
--
-- 3. The cache invalidation triggers delete from match_cache_v2 with
--    `user_id = $1 or candidate_id = $1`, and only user_id was indexed, so
--    each invalidation scanned the whole cache table.
--
-- Rollback note: match_cards is defined in 20261125000100_match_cards.sql;
-- replaying that file restores the previous body. The indexes are additive.

-- ---------------------------------------------------------------------------
-- 1. ANN retrieval for possible-match recipients
-- ---------------------------------------------------------------------------
create index if not exists profile_embeddings_ann_query_skills_learner
  on public.profile_embeddings
  using hnsw (embedding extensions.vector_cosine_ops)
  where input_type = 'query'
    and field_group = 'skills'::public.embed_field_group
    and role = 'learner'::public.embed_role;

create index if not exists profile_embeddings_ann_query_skills_mentor
  on public.profile_embeddings
  using hnsw (embedding extensions.vector_cosine_ops)
  where input_type = 'query'
    and field_group = 'skills'::public.embed_field_group
    and role = 'mentor'::public.embed_role;

-- ---------------------------------------------------------------------------
-- 1b. Keep the ANN scan honest at recall_k
--
-- An HNSW scan yields at most hnsw.ef_search tuples (default 40), so a LIMIT
-- of recall_k=200 would silently shrink to ~40 recipients once the planner
-- starts using the index. Pin ef_search to the configured recall.
-- ---------------------------------------------------------------------------
alter function public.possible_match_recipients(uuid, integer)
  set hnsw.ef_search = 200;

-- ---------------------------------------------------------------------------
-- 2. match_cards: resolve context per gated candidate, not per platform user
-- ---------------------------------------------------------------------------
create or replace function public.match_cards(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_min_skill real,
  p_require_media boolean,
  p_w_skills real,
  p_w_context real
) returns table (
  candidate_id uuid,
  card_id uuid,
  source_card_id uuid,
  skill_id uuid,
  skill_name text,
  skill_path text,
  skill_kind public.skill_kind,
  skill_score real,
  bi_score real
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
me as (
  select us.id as card_id, us.kind, n.path
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  where us.user_id = p_user
    and us.visibility = 'discoverable'
    and us.kind = case when p_target = 'mentor'
                       then 'learn'::public.skill_kind
                       else 'teach'::public.skill_kind end
    and n.kind = 'skill'
    and n.status = 'approved'
),
pairs as (
  select c.user_id as candidate_id,
         c.id as card_id,
         m.card_id as source_card_id,
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
  join me m on public.skill_pair_score(m.path, n.path) >= p_min_skill
  cross join target_kind tk
  where c.kind = tk.k
    and c.user_id <> p_user
    and c.visibility = 'discoverable'
    and public.side_ready(c.user_id, tk.k)
    and (
      not p_require_media
      or c.kind <> 'teach'::public.skill_kind
      or public.has_discovery_media(c.user_id)
    )
    and not exists (select 1 from blocked b where b.uid = c.user_id)
    and not exists (select 1 from connected cn where cn.uid = c.user_id)
    and not exists (select 1 from reported rp where rp.uid = c.user_id)
  group by c.user_id, c.id, m.card_id, c.skill_id, n.name, n.path, c.kind
),
card_bi as (
  select p.candidate_id, p.card_id, p.source_card_id,
         max(1 - extensions.cosine_distance(mq.embedding, cp.embedding))::real as sim
  from pairs p
  join public.card_embeddings cp
    on cp.card_id = p.card_id
   and cp.input_type = 'passage'
   and cp.model_name = (select name from model)
  join public.card_embeddings mq
    on mq.card_id = p.source_card_id
   and mq.input_type = 'query'
   and mq.model_name = (select name from model)
  group by p.candidate_id, p.card_id, p.source_card_id
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query'
    and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
    and model_name = (select name from model)
),
-- Only cards that survived the skill gate can consume context similarity.
cands as (
  select distinct p.candidate_id from pairs p
),
ctx as (
  select e.user_id,
         (1 - extensions.cosine_distance(c_me.embedding, e.embedding))::real as sim
  from public.profile_embeddings e
  join cands cd on cd.candidate_id = e.user_id
  cross join c_me
  where e.role = p_target
    and e.input_type = 'passage'
    and e.field_group = 'context'::public.embed_field_group
    and e.model_name = (select name from model)
),
ranked as (
  select p.candidate_id,
         p.card_id,
         p.source_card_id,
         p.skill_id,
         p.skill_name,
         p.skill_path,
         p.skill_kind,
         p.skill_score,
         (p_w_skills * coalesce(cb.sim, p.skill_score)
          + p_w_context * coalesce(ctx.sim, 0))::real as bi_score
  from pairs p
  left join card_bi cb
    on cb.candidate_id = p.candidate_id
   and cb.card_id = p.card_id
   and cb.source_card_id = p.source_card_id
  left join ctx on ctx.user_id = p.candidate_id
),
best as (
  select distinct on (r.card_id)
    r.candidate_id, r.card_id, r.source_card_id, r.skill_id, r.skill_name,
    r.skill_path, r.skill_kind, r.skill_score, r.bi_score
  from ranked r
  order by r.card_id, r.bi_score desc, r.skill_score desc
)
select b.candidate_id, b.card_id, b.source_card_id, b.skill_id, b.skill_name,
       b.skill_path, b.skill_kind, b.skill_score, b.bi_score
from best b
where coalesce(auth.role(), '') = 'service_role' or p_user = auth.uid()
order by b.bi_score desc
limit p_limit;
$$;

revoke all on function public.match_cards(
  uuid, public.embed_role, integer, real, boolean, real, real
) from public, anon;
grant execute on function public.match_cards(
  uuid, public.embed_role, integer, real, boolean, real, real
) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Cache invalidation by candidate
-- ---------------------------------------------------------------------------
create index if not exists idx_matchcache_v2_candidate
  on public.match_cache_v2 (candidate_id);
