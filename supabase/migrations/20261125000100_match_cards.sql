-- Phase 2 of the card-level matching rework: card-pair retrieval + cache.
--
-- match_cards returns one row per compatible (my card, their card) pair, so a
-- person can legitimately appear for more than one skill. The profile-level
-- match_candidates/match_cache path is untouched and remains the rollback.
--
-- Gates mirror 20261121000800 (side_ready, blocks, connections, reports) and
-- 20261121000300 (model-aware vectors). Media is gated per side because
-- skill_showcases.skill_id is still derived from a caption match and is often
-- null; side readiness is the reliable signal today.

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
ctx as (
  select e.user_id,
         (1 - extensions.cosine_distance(c_me.embedding, e.embedding))::real as sim
  from public.profile_embeddings e cross join c_me
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

create table if not exists public.match_cache_v2 (
  user_id uuid not null references public.profiles(id) on delete cascade,
  as_role public.embed_role not null,
  source_card_id uuid not null references public.user_skills(id) on delete cascade,
  candidate_card_id uuid not null references public.user_skills(id) on delete cascade,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  rank integer not null,
  bi_score real,
  rerank_score_a real,
  rerank_score_b real,
  reciprocal_score real not null,
  calibrated_score real not null,
  pipeline_mode text not null default 'full',
  display_name text,
  role text,
  skill_name text,
  skill_path text,
  skill_kind public.skill_kind,
  model_name text not null,
  config_version integer not null,
  refreshed_at timestamp with time zone default now() not null,
  primary key (user_id, as_role, source_card_id, candidate_card_id)
);

create index if not exists idx_matchcache_v2_rank
  on public.match_cache_v2 (user_id, as_role, rank);

alter table public.match_cache_v2 enable row level security;

drop policy if exists "cache_v2_owner_read" on public.match_cache_v2;
create policy "cache_v2_owner_read"
  on public.match_cache_v2
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.match_cache_v2 from anon, authenticated;
grant select on public.match_cache_v2 to authenticated;
grant all on public.match_cache_v2 to service_role;

create or replace function public.cache_is_fresh_v2(
  p_user uuid,
  p_role public.embed_role,
  p_revision integer
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
      select 1
      from public.match_cache_v2
      where user_id = p_user and as_role = p_role
    )
    and not exists (
      select 1
      from public.match_cache_v2 mc
      join public.profiles own on own.id = mc.user_id
      where mc.user_id = p_user
        and mc.as_role = p_role
        and (
          mc.config_version <> p_revision
          or mc.refreshed_at <= own.updated_at
          or exists (
            select 1 from public.user_skills ownus
            where ownus.user_id = p_user
              and ownus.updated_at > mc.refreshed_at
          )
          or exists (
            select 1 from public.profiles cand
            where cand.id = mc.candidate_id
              and cand.updated_at > mc.refreshed_at
          )
          or exists (
            select 1 from public.user_skills cs
            where cs.id in (mc.candidate_card_id, mc.source_card_id)
              and cs.updated_at > mc.refreshed_at
          )
          or exists (
            select 1
            from public.skill_showcases sc
            where sc.skill_id = (
              select us.skill_id from public.user_skills us
              where us.id = mc.candidate_card_id
            )
              and sc.updated_at > mc.refreshed_at
          )
        )
    )
$$;

revoke all on function public.cache_is_fresh_v2(uuid, public.embed_role, integer)
  from public, anon;
grant execute on function public.cache_is_fresh_v2(uuid, public.embed_role, integer)
  to authenticated, service_role;

-- Note/approval edits already invalidate match_cache. Extend the same trigger
-- to the card cache, then cover visibility and showcase changes.
create or replace function public.invalidate_note_visibility_cache()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'UPDATE'
     and new.note is not distinct from old.note
     and new.note_approved is not distinct from old.note_approved then
    return null;
  end if;

  delete from public.match_cache
  where user_id = new.user_id or candidate_id = new.user_id;
  delete from public.match_cache_v2
  where user_id = new.user_id or candidate_id = new.user_id;

  return null;
end;
$$;

revoke all on function public.invalidate_note_visibility_cache()
  from public, anon, authenticated;

create or replace function public.invalidate_card_cache()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user uuid := coalesce(new.user_id, old.user_id);
begin
  delete from public.match_cache_v2
  where user_id = v_user or candidate_id = v_user;
  return null;
end;
$$;

revoke all on function public.invalidate_card_cache()
  from public, anon, authenticated;

drop trigger if exists trg_user_skills_visibility_cache on public.user_skills;
create trigger trg_user_skills_visibility_cache
  after update of visibility on public.user_skills
  for each row
  execute function public.invalidate_card_cache();

drop trigger if exists trg_skill_showcases_card_cache on public.skill_showcases;
create trigger trg_skill_showcases_card_cache
  after insert or update or delete on public.skill_showcases
  for each row
  execute function public.invalidate_card_cache();
