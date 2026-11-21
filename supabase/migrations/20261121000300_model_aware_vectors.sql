-- Provider-aware candidate retrieval.
--
-- match_candidates compared whatever vectors were stored, regardless of the
-- model that produced them. After a provider switch (NVIDIA <-> DeepInfra)
-- that mixes vector spaces, so only rows from the active embedding model are
-- eligible. Stale rows are also purged on publish; this is defence in depth.

create or replace function public.match_candidates(
  p_user uuid,
  p_target embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real
)
returns table(candidate_id uuid, bi_score real)
language sql
stable
security definer
set search_path to 'public'
as $$
with seeker as (
  select (case when p_target = 'mentor' then 'learner' else 'mentor' end)::public.embed_role as s_role
),
target_kind as (
  select (case when p_target = 'mentor' then 'teach' else 'learn' end)::public.skill_kind as k
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
s_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'skills'::public.embed_field_group
    and model_name = (select name from model)
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
    and model_name = (select name from model)
),
s_sc as (
  select e.user_id, (1 - extensions.cosine_distance(s_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join s_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'skills'::public.embed_field_group
    and e.model_name = (select name from model)
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
    and not exists (select 1 from connected cn where cn.uid = e.user_id)
    and not exists (select 1 from reported rp where rp.uid = e.user_id)
),
c_sc as (
  select e.user_id, (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'context'::public.embed_field_group
    and e.model_name = (select name from model)
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
    and not exists (select 1 from connected cn where cn.uid = e.user_id)
    and not exists (select 1 from reported rp where rp.uid = e.user_id)
),
fallback as (
  select distinct us.user_id
  from public.user_skills us
  cross join target_kind tk
  join public.skill_nodes n
    on n.id = us.skill_id
   and n.kind = 'skill'
   and n.status = 'approved'
  join public.profiles pf on pf.id = us.user_id and pf.has_completed_onboarding
  where us.kind = tk.k
    and us.user_id <> p_user
    and (p_target = 'learner' or public.has_discovery_media(us.user_id))
    and not exists (select 1 from blocked b where b.uid = us.user_id)
    and not exists (select 1 from connected cn where cn.uid = us.user_id)
    and not exists (select 1 from reported rp where rp.uid = us.user_id)
  limit 200
),
u as (
  select user_id from s_sc
  union
  select user_id from c_sc
  union
  select user_id from fallback
)
select u.user_id,
  (p_w_skills * coalesce(s_sc.sim, 0) + p_w_context * coalesce(c_sc.sim, 0))::real
from u
left join s_sc on s_sc.user_id = u.user_id
left join c_sc on c_sc.user_id = u.user_id
join public.profiles pf on pf.id = u.user_id and pf.has_completed_onboarding
where not exists (select 1 from blocked b where b.uid = u.user_id)
  and not exists (select 1 from connected cn where cn.uid = u.user_id)
  and not exists (select 1 from reported rp where rp.uid = u.user_id)
  and (p_target = 'learner' or public.has_discovery_media(u.user_id))
  and (
    coalesce(auth.role(), '') = 'service_role'
    or p_user = auth.uid()
  )
order by 2 desc
limit p_limit;
$$;
