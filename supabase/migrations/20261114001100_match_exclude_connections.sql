-- For You could still show an existing Pal or a pending request because
-- match_candidates only filtered blocks. Exclude connections and clear the
-- cached deck whenever a connection is created, answered, or removed.

create or replace function public.invalidate_connection_match_cache()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  a uuid;
  b uuid;
begin
  if tg_op = 'DELETE' then
    a := old.requester_id;
    b := old.recipient_id;
  else
    a := new.requester_id;
    b := new.recipient_id;
  end if;

  delete from public.match_cache where user_id in (a, b);
  return null;
end;
$$;

drop trigger if exists invalidate_connection_match_cache on public.connections;
create trigger invalidate_connection_match_cache
  after insert or update of status or delete on public.connections
  for each row execute function public.invalidate_connection_match_cache();

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
    and not exists (
      select 1 from public.connections c
      where (c.requester_id = p_user and c.recipient_id = us.user_id)
         or (c.requester_id = us.user_id and c.recipient_id = p_user)
    )
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
  and not exists (
    select 1 from public.connections c
    where (c.requester_id = p_user and c.recipient_id = u.user_id)
       or (c.requester_id = u.user_id and c.recipient_id = p_user)
  )
  and (
    coalesce(auth.role(), '') = 'service_role'
    or p_user = auth.uid()
  )
order by 2 desc
limit p_limit;
$$;
