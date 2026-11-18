-- Counts for one Browse node (a domain or a skill).
--
-- The domain page needs the total population, not just the people the viewer
-- has not connected with, so the empty state can say "you're already matched
-- with X" instead of contradicting the card count.

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
    and public.has_discovery_media(p.id)
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
         where (c.requester_id = me.uid and c.recipient_id = e.user_id)
            or (c.requester_id = e.user_id and c.recipient_id = me.uid)
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
