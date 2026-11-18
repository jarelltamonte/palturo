-- "New" now means recently registered, not new-to-you.
--
-- The overview shows each domain's full population. A domain also gets a
-- "· N new" suffix when N of those people registered in the last seven days.
-- `fresh` stays in the payload so the daily featured pick can prefer a domain
-- with someone the viewer has not connected with yet, but the cards no longer
-- display it.

-- `create or replace` cannot add an OUT column, so drop and recreate.
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
           where (c.requester_id = me.uid and c.recipient_id = e.user_id)
              or (c.requester_id = e.user_id and c.recipient_id = me.uid)
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
