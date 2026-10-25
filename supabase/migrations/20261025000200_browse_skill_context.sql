-- Browse cards need the same decision context as For You. Extend the browse
-- RPC with profile facts instead of rebuilding those fields client-side.

drop function if exists public.browse_skill_users(text, public.skill_kind, integer);

create or replace function public.browse_skill_users(
  p_node text,
  p_kind public.skill_kind default 'teach'::public.skill_kind,
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
  skill_name text
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
    n.name
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  where (p_node::extensions.ltree @> n.path)
    and us.kind = p_kind
    and n.status = 'approved'
    and p.has_completed_onboarding
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

revoke all on function public.browse_skill_users(text, public.skill_kind, integer) from public;
grant execute on function public.browse_skill_users(text, public.skill_kind, integer) to authenticated;
grant execute on function public.browse_skill_users(text, public.skill_kind, integer) to service_role;
