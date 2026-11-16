-- The editor tells mentors they stay out of discovery until they add a
-- showcase, but every discovery query only checked onboarding. Enforce the
-- promise: a teaching profile needs showcase media to appear in Browse,
-- Explore, or the For You matcher. Learners are unaffected.

create or replace function public.has_discovery_media(p_user uuid)
returns boolean
language sql
stable
set search_path = 'public'
as $$
  select not exists (
      select 1 from public.user_skills us
      where us.user_id = p_user and us.kind = 'teach'
    )
    or exists (
      select 1 from public.skill_showcases s where s.user_id = p_user
    )
    or coalesce((
      select p.teaching_skill_images <> '{}'::jsonb
      from public.profiles p where p.id = p_user
    ), false);
$$;

revoke all on function public.has_discovery_media(uuid)
  from public, anon, authenticated;

create or replace function public.browse_random_users(p_limit integer default 20)
returns table (
  user_id uuid,
  name text,
  role text,
  avatar_url text,
  bio text
)
language sql
security definer
set search_path to 'public'
as $$
  select p.id, coalesce(p.display_name, ''), p.role::text, p.avatar_url, p.bio
  from public.profiles p
  where p.has_completed_onboarding
    and p.id <> auth.uid()
    and public.has_discovery_media(p.id)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
    and not exists (
      select 1 from public.connections c
      where (c.requester_id = auth.uid() and c.recipient_id = p.id)
         or (c.requester_id = p.id and c.recipient_id = auth.uid())
    )
  order by random()
  limit greatest(1, least(coalesce(p_limit, 20), 200));
$$;

create or replace function public.browse_skill_users(
  p_node text,
  p_kind public.skill_kind default 'teach',
  p_limit integer default 50
)
returns table (
  user_id uuid,
  name text,
  role text,
  avatar_url text,
  note text,
  availability jsonb,
  languages text[],
  learning_styles text[],
  skill_name text,
  skill_path text
)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $$
  select distinct on (us.user_id)
    us.user_id,
    coalesce(p.display_name, ''),
    p.role::text,
    p.avatar_url,
    case when us.note_approved then us.note else null end,
    coalesce(p.availability, '{}'::jsonb),
    coalesce(p.languages, '{}'::text[]),
    coalesce(p.learning_styles, '{}'::text[]),
    n.name,
    n.path::text
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  where (p_node::extensions.ltree @> n.path)
    and us.kind = p_kind
    and n.status = 'approved'
    and p.has_completed_onboarding
    and public.has_discovery_media(p.id)
    and (auth.uid() is null or us.user_id <> auth.uid())
    and not exists (
      select 1
      from public.blocks b
      where auth.uid() is not null
        and ((b.blocker_id = auth.uid() and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = auth.uid()))
    )
  order by us.user_id, n.usage_count desc, n.name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

create or replace function public.match_candidates(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real
)
returns table (candidate_id uuid, bi_score real)
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
s_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'skills'::public.embed_field_group
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
),
s_sc as (
  select e.user_id, (1 - extensions.cosine_distance(s_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join s_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'skills'::public.embed_field_group
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
),
c_sc as (
  select e.user_id, (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'context'::public.embed_field_group
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
),
fallback as (
  select distinct us.user_id
  from public.user_skills us
  cross join target_kind tk
  join public.profiles pf on pf.id = us.user_id and pf.has_completed_onboarding
  where us.kind = tk.k
    and us.user_id <> p_user
    and public.has_discovery_media(us.user_id)
    and not exists (select 1 from blocked b where b.uid = us.user_id)
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
  and public.has_discovery_media(u.user_id)
  and (
    coalesce(auth.role(), '') = 'service_role'
    or p_user = auth.uid()
  )
order by 2 desc
limit p_limit;
$$;
