-- The receiver's declared domains live in user_skills/skill_nodes, not in the
-- legacy profiles.skill_categories bucket strings. Use taxonomy ancestry so
-- both legacy profile data and terminal leaf skills match correctly.

drop function if exists public.get_incoming_requests(integer);

create or replace function public.get_incoming_requests(p_limit integer default 25)
returns table (
  connection_id uuid,
  requester_id uuid,
  requester_name text,
  requester_role text,
  avatar_url text,
  skills text[],
  requested_skill_name text,
  requested_skill_path text,
  in_declared_domain boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $$
with mine as (
  select * from public.connections
  where recipient_id = auth.uid() and status = 'pending'
),
sk as (
  select us.user_id,
    coalesce(array_agg(distinct n.name order by n.name), '{}') as skills
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  group by us.user_id
)
select
  m.id,
  m.requester_id,
  coalesce(p.display_name, ''),
  p.role::text,
  p.avatar_url,
  sk.skills,
  coalesce(m.skill_name, (sk.skills)[1]),
  m.skill_path,
  case
    when m.skill_path is null then null
    else exists (
      select 1
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.user_id = auth.uid()
        and n.path @> m.skill_path::extensions.ltree
    )
  end,
  m.created_at
from mine m
join public.profiles p on p.id = m.requester_id
left join sk on sk.user_id = m.requester_id
order by m.created_at desc
limit greatest(1, least(coalesce(p_limit, 25), 100));
$$;

revoke all on function public.get_incoming_requests(integer) from public, anon;
grant execute on function public.get_incoming_requests(integer)
  to authenticated, service_role;
