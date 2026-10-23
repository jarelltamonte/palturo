-- B5/B6: internal RPCs must not be callable by clients.
--
--   notify(p_user, p_kind, p_payload)  -> arbitrary notification insert
--   match_candidates(p_user, ...)      -> arbitrary user's candidate list
--
-- Both are SECURITY DEFINER and were executable by PUBLIC, anon and
-- authenticated. They are only used by other SECURITY DEFINER functions
-- (which run as the owner) and by the get-matches Edge Function (service role).

revoke all on function public.notify(uuid, text, jsonb) from public;
revoke all on function public.notify(uuid, text, jsonb) from anon;
revoke all on function public.notify(uuid, text, jsonb) from authenticated;
grant execute on function public.notify(uuid, text, jsonb) to service_role;

revoke all on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) from public;
revoke all on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) from anon;
revoke all on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) from authenticated;
grant execute on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) to service_role;

-- Defense in depth: even if this is ever re-granted, a signed-in caller can
-- only ask for their own candidates. The Edge Function calls it with the
-- service role, which carries request.jwt.claim.role = 'service_role'.
create or replace function public.match_candidates(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real
)
returns table(candidate_id uuid, bi_score real)
language sql
stable
security definer
set search_path to 'public'
as $function$
with seeker as (
  select (case when p_target = 'mentor' then 'learner' else 'mentor' end)::public.embed_role as s_role
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
u as (
  select user_id from s_sc union select user_id from c_sc
)
select u.user_id,
  (p_w_skills * coalesce(s_sc.sim, 0) + p_w_context * coalesce(c_sc.sim, 0))::real
from u
left join s_sc on s_sc.user_id = u.user_id
left join c_sc on c_sc.user_id = u.user_id
join public.profiles pf on pf.id = u.user_id and pf.has_completed_onboarding
where not exists (select 1 from blocked b where b.uid = u.user_id)
  and (
    coalesce(auth.role(), '') = 'service_role'
    or p_user = auth.uid()
  )
order by 2 desc
limit p_limit;
$function$;
