-- Sandbox gets its own schema so a run never reads or writes production match
-- state. Retrieval and scoring are simulated against a snapshot of the
-- matching tables; every write stays inside `sandbox`, and the matcher helpers
-- that only describe readiness (side_ready, has_discovery_media) are still read
-- from public because they are not tunable.
--
-- Snapshot refresh is bounded by a TTL so repeated sandbox runs do not copy the
-- taxonomy on every click.

create schema if not exists sandbox;

revoke all on schema sandbox from public;
grant usage on schema sandbox to service_role;

create table if not exists sandbox.profiles (
  like public.profiles including defaults
);
create table if not exists sandbox.skill_nodes (
  like public.skill_nodes including defaults
);
create table if not exists sandbox.user_skills (
  like public.user_skills including defaults
);
create table if not exists sandbox.profile_embeddings (
  like public.profile_embeddings including defaults
);
create table if not exists sandbox.card_embeddings (
  like public.card_embeddings including defaults
);
create table if not exists sandbox.snapshot (
  id bigserial primary key,
  snapshotted_at timestamptz not null default now()
);

create index if not exists sandbox_user_skills_user on sandbox.user_skills (user_id);
create index if not exists sandbox_user_skills_skill on sandbox.user_skills (skill_id);
create index if not exists sandbox_skill_nodes_path on sandbox.skill_nodes using gist (path);
create index if not exists sandbox_profile_embeddings_user on sandbox.profile_embeddings (user_id);

create or replace function public.sandbox_refresh(p_max_age_seconds integer default 600)
returns jsonb
language plpgsql
security definer
set search_path = public, sandbox
as $$
declare
  v_last timestamptz;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden';
  end if;

  select max(snapshotted_at) into v_last from sandbox.snapshot;
  if v_last is not null
     and now() - v_last < make_interval(secs => greatest(0, p_max_age_seconds)) then
    return jsonb_build_object('refreshed', false, 'snapshot_at', v_last);
  end if;

  truncate sandbox.profiles, sandbox.skill_nodes, sandbox.user_skills,
           sandbox.profile_embeddings, sandbox.card_embeddings;

  insert into sandbox.profiles select * from public.profiles;
  insert into sandbox.skill_nodes select * from public.skill_nodes;
  insert into sandbox.user_skills select * from public.user_skills;
  insert into sandbox.profile_embeddings select * from public.profile_embeddings;
  insert into sandbox.card_embeddings select * from public.card_embeddings;
  insert into sandbox.snapshot default values;

  return jsonb_build_object('refreshed', true, 'snapshot_at', now());
end;
$$;

revoke all on function public.sandbox_refresh(integer) from public, anon, authenticated;
grant execute on function public.sandbox_refresh(integer) to service_role;

-- Retrieval against the snapshot. Same shape and scoring as public.match_cards,
-- but every matching table is the sandbox copy. Readiness gates stay public:
-- they describe the live account, not a tunable.
create or replace function public.sandbox_match_cards(
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
set search_path = public, sandbox, extensions
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
  from sandbox.user_skills us
  join sandbox.skill_nodes n on n.id = us.skill_id
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
  from sandbox.user_skills c
  join sandbox.skill_nodes n
    on n.id = c.skill_id
   and n.kind = 'skill'
   and n.status = 'approved'
  join sandbox.profiles p on p.id = c.user_id and p.has_completed_onboarding
  join me m on (
      n.path <@ m.path
      or m.path <@ n.path
      or (p_min_skill <= 0.45
          and nlevel(m.path) > 1
          and nlevel(n.path) > 1
          and subpath(m.path, 0, nlevel(m.path) - 1)
              = subpath(n.path, 0, nlevel(n.path) - 1))
      or p_min_skill <= 0
    )
    and public.skill_pair_score(m.path, n.path) >= p_min_skill
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
  join sandbox.card_embeddings cp
    on cp.card_id = p.card_id
   and cp.input_type = 'passage'
   and cp.model_name = (select name from model)
  join sandbox.card_embeddings mq
    on mq.card_id = p.source_card_id
   and mq.input_type = 'query'
   and mq.model_name = (select name from model)
  group by p.candidate_id, p.card_id, p.source_card_id
),
c_me as (
  select embedding from sandbox.profile_embeddings
  where user_id = p_user and input_type = 'query'
    and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
    and model_name = (select name from model)
),
cands as (
  select distinct p.candidate_id from pairs p
),
ctx as (
  select e.user_id,
         (1 - extensions.cosine_distance(c_me.embedding, e.embedding))::real as sim
  from sandbox.profile_embeddings e
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
where coalesce(auth.role(), '') = 'service_role'
order by b.bi_score desc
limit p_limit;
$$;

revoke all on function public.sandbox_match_cards(
  uuid, public.embed_role, integer, real, boolean, real, real
) from public, anon, authenticated;
grant execute on function public.sandbox_match_cards(
  uuid, public.embed_role, integer, real, boolean, real, real
) to service_role;
