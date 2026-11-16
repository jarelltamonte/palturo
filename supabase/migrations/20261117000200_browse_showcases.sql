-- Browse cards only carried the avatar, so every deck card showed a single
-- photo and the showcase media never appeared. Return the person's showcases
-- with the browse row, mirroring what get_public_profile already returns for
-- For You.

drop function if exists public.browse_skill_users(text, public.skill_kind, integer);

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
  skill_path text,
  showcases jsonb
)
language sql
stable
security definer
set search_path = 'public', 'extensions'
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

revoke all on function public.browse_skill_users(text, public.skill_kind, integer)
  from public, anon;
grant execute on function public.browse_skill_users(text, public.skill_kind, integer)
  to authenticated, service_role;
