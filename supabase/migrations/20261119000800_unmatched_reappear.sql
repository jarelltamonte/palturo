-- Unmatched connections keep their row for moderation but are no longer an
-- active pair, so both users can reappear in each other's discovery.

-- Declined requests should not permanently remove both users from each
-- other's discovery. Only pending/accepted connections are considered active.
-- This re-runs the role-aware discovery functions with that filter.

-- The showcase gate is per role, not per profile.
--
-- A profile can teach and learn. Requiring showcase media whenever a profile
-- has any teach skill hid learners who also teach from the mentor's For You
-- deck and from Browse's learner side. Learners never need a showcase; the
-- gate now applies only when the candidate is being discovered as a mentor.
-- Browse by role uses p_kind, the matcher uses p_target, and the random deck
-- keeps the gate for mentor/both profiles because it presents them as mentors.

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
  teaching_styles text[],
  skill_name text,
  skill_path text,
  showcases jsonb
)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
  select distinct on (us.user_id)
    us.user_id,
    coalesce(p.display_name, ''),
    p.role::text,
    p.avatar_url,
    case when us.note_approved then us.note else null end,
    coalesce(p.availability, '{}'::jsonb),
    coalesce(p.languages, '{}'::text[]),
    coalesce(p.learning_styles, '{}'::text[]),
    coalesce(p.teaching_styles, '{}'::text[]),
    n.name,
    n.path::text,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'media', sc.media_url,
          'kind', sc.media_kind::text,
          'thumb', sc.thumbnail_url,
          'skill', sn.name,
          'caption', sc.caption
        )
        order by sc.created_at
      )
      from public.skill_showcases sc
      left join public.skill_nodes sn on sn.id = sc.skill_id
      where sc.user_id = us.user_id
    ), '[]'::jsonb)
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  where (p_node::extensions.ltree @> n.path)
    and n.kind = 'skill'
    and us.kind = p_kind
    and n.status = 'approved'
    and p.has_completed_onboarding
    and (p_kind = 'learn' or public.has_discovery_media(p.id))
    and (auth.uid() is null or us.user_id <> auth.uid())
    and not exists (
      select 1
      from public.blocks b
      where auth.uid() is not null
        and ((b.blocker_id = auth.uid() and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = auth.uid()))
    )
    and not exists (
      select 1
      from public.connections c
      where auth.uid() is not null
        and c.status in ('pending', 'accepted') and c.unmatched_at is null
        and ((c.requester_id = auth.uid() and c.recipient_id = us.user_id)
          or (c.requester_id = us.user_id and c.recipient_id = auth.uid()))
    )
    and not exists (
      select 1
      from public.reports r
      where auth.uid() is not null
        and ((r.reporter_id = auth.uid() and r.reported_id = us.user_id)
          or (r.reporter_id = us.user_id and r.reported_id = auth.uid()))
    )
  order by us.user_id, n.usage_count desc, n.name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$function$;

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
    and (p.role = 'learner' or public.has_discovery_media(p.id))
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
    and not exists (
      select 1 from public.connections c
      where c.status in ('pending', 'accepted') and c.unmatched_at is null
        and ((c.requester_id = auth.uid() and c.recipient_id = p.id)
          or (c.requester_id = p.id and c.recipient_id = auth.uid()))
    )
    and not exists (
      select 1 from public.reports r
      where (r.reporter_id = auth.uid() and r.reported_id = p.id)
         or (r.reporter_id = p.id and r.reported_id = auth.uid())
    )
  order by random()
  limit greatest(1, least(coalesce(p_limit, 20), 200));
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
set search_path = 'public'
as $function$
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
    and not exists (select 1 from connected cn where cn.uid = e.user_id)
    and not exists (select 1 from reported rp where rp.uid = e.user_id)
),
c_sc as (
  select e.user_id, (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'context'::public.embed_field_group
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
$function$;

drop function if exists public.browse_domain_counts(public.skill_kind);

create or replace function public.browse_domain_counts(
  p_kind public.skill_kind default 'teach'
)
returns table (root_path text, total integer, fresh integer, newcomers integer)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
with me as (
  select auth.uid() as uid
),
eligible as (
  select distinct us.user_id, root.path::text as root_path, p.created_at
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.skill_nodes root
    on root.kind = 'category'
   and root.depth = 1
   and root.path::text = split_part(n.path::text, '.', 1)
  join public.profiles p on p.id = us.user_id
  cross join me
  where us.kind = p_kind
    and n.kind = 'skill'
    and n.status = 'approved'
    and p.has_completed_onboarding
    and (p_kind = 'learn' or public.has_discovery_media(p.id))
    and (me.uid is null or us.user_id <> me.uid)
    and not exists (
      select 1
      from public.blocks b
      where me.uid is not null
        and ((b.blocker_id = me.uid and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = me.uid))
    )
    and not exists (
      select 1
      from public.reports r
      where me.uid is not null
        and ((r.reporter_id = me.uid and r.reported_id = us.user_id)
          or (r.reporter_id = us.user_id and r.reported_id = me.uid))
    )
),
counts as (
  select
    e.root_path,
    count(*)::int as total,
    count(*) filter (
      where me.uid is null
         or not exists (
           select 1
           from public.connections c
           where c.status in ('pending', 'accepted') and c.unmatched_at is null
             and ((c.requester_id = me.uid and c.recipient_id = e.user_id)
               or (c.requester_id = e.user_id and c.recipient_id = me.uid))
         )
    )::int as fresh,
    count(*) filter (
      where e.created_at >= now() - interval '7 days'
    )::int as newcomers
  from eligible e
  cross join me
  group by e.root_path
)
select
  root.path::text,
  coalesce(c.total, 0),
  coalesce(c.fresh, 0),
  coalesce(c.newcomers, 0)
from public.skill_nodes root
left join counts c on c.root_path = root.path::text
where root.kind = 'category'
  and root.depth = 1
order by root.path;
$function$;

revoke all on function public.browse_domain_counts(public.skill_kind)
  from public, anon;
grant execute on function public.browse_domain_counts(public.skill_kind)
  to authenticated, service_role;


drop function if exists public.browse_people_counts(text, public.skill_kind);

create function public.browse_people_counts(
  p_node text,
  p_kind public.skill_kind default 'teach'
)
returns table (total integer, fresh integer, newcomers integer)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
with me as (
  select auth.uid() as uid
),
eligible as (
  select distinct us.user_id, p.created_at
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  cross join me
  where (p_node::extensions.ltree @> n.path)
    and n.kind = 'skill'
    and n.status = 'approved'
    and us.kind = p_kind
    and p.has_completed_onboarding
    and (p_kind = 'learn' or public.has_discovery_media(p.id))
    and (me.uid is null or us.user_id <> me.uid)
    and not exists (
      select 1
      from public.blocks b
      where me.uid is not null
        and ((b.blocker_id = me.uid and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = me.uid))
    )
    and not exists (
      select 1
      from public.reports r
      where me.uid is not null
        and ((r.reporter_id = me.uid and r.reported_id = us.user_id)
          or (r.reporter_id = us.user_id and r.reported_id = me.uid))
    )
)
select
  count(*)::int as total,
  count(*) filter (
    where me.uid is null
       or not exists (
         select 1
         from public.connections c
         where c.status in ('pending', 'accepted') and c.unmatched_at is null
           and ((c.requester_id = me.uid and c.recipient_id = e.user_id)
             or (c.requester_id = e.user_id and c.recipient_id = me.uid))
       )
  )::int as fresh,
  count(*) filter (
    where e.created_at >= now() - interval '7 days'
  )::int as newcomers
from eligible e
cross join me;
$function$;

revoke all on function public.browse_people_counts(text, public.skill_kind)
  from public, anon;
grant execute on function public.browse_people_counts(text, public.skill_kind)
  to authenticated, service_role;

