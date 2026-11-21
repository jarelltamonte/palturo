-- Phase 1 of the card-level matching rework: per-card visibility and vectors.
--
-- Card identity is user_skills.id. That table already owns the caps, note
-- moderation, and ON DELETE CASCADE links, so no parallel card table is needed
-- yet. Everything here is additive and safe to run while the profile matcher is
-- still live.
--
-- Rollback: drop card_embeddings and the visibility column. No existing data is
-- modified beyond the column default.

alter table public.user_skills
  add column if not exists visibility text not null default 'discoverable';

alter table public.user_skills
  drop constraint if exists user_skills_visibility_check;
alter table public.user_skills
  add constraint user_skills_visibility_check
  check (visibility in ('discoverable', 'paused', 'hidden'));

create index if not exists idx_uskills_discoverable
  on public.user_skills (kind, skill_id)
  where visibility = 'discoverable';

create table if not exists public.card_embeddings (
  card_id uuid not null references public.user_skills(id) on delete cascade,
  input_type text not null default 'passage'
    check (input_type in ('passage', 'query')),
  source_text text not null,
  source_hash text not null,
  model_name text not null,
  embedding extensions.vector(1024) not null,
  updated_at timestamp with time zone default now() not null,
  primary key (card_id, input_type)
);

create index if not exists idx_card_embeddings_hnsw
  on public.card_embeddings
  using hnsw (embedding extensions.vector_cosine_ops);

alter table public.card_embeddings enable row level security;

-- Service role only: card vectors must never be readable by clients.
revoke all on public.card_embeddings from public, anon, authenticated;
grant all on public.card_embeddings to service_role;

-- One canonical passage per card: skill chain + approved note.
create or replace function public.build_card_passages_bulk(p_cards uuid[])
returns table (
  card_id uuid,
  user_id uuid,
  source_text text,
  source_hash text
)
language sql
stable
set search_path = public, extensions
as $$
with declared as (
  select us.id,
         us.user_id,
         us.kind,
         us.note,
         us.note_approved,
         leaf.name,
         leaf.path
  from public.user_skills us
  join public.skill_nodes leaf on leaf.id = us.skill_id
  where us.id = any (p_cards)
    and leaf.is_leaf
),
txt as (
  select d.id,
         d.user_id,
         case d.kind
           when 'teach' then 'Offers to teach: '
           when 'learn' then 'Wants to learn: '
           else 'Skill: '
         end
         || coalesce((
              select string_agg(a.name, ' > ' order by a.depth)
              from public.skill_nodes a
              where a.path @> d.path
            ), d.name)
         || case
              when d.note_approved and coalesce(d.note, '') <> ''
                then ' - note: ' || d.note
              else ''
            end as passage_text
  from declared d
)
select t.id, t.user_id, t.passage_text, md5(t.passage_text)
from txt t
where btrim(t.passage_text) <> '';
$$;

revoke all on function public.build_card_passages_bulk(uuid[]) from public, anon;
grant execute on function public.build_card_passages_bulk(uuid[])
  to service_role;
