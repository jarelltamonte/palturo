-- Scope showcase media to the card that shows it.
--
-- A card is one user_skills row: one skill, one side. Showcase media was
-- returned per profile and attached to every card, so a mentor's teaching clip
-- appeared on "wants to learn X" cards and, for a user teaching two skills, on
-- the card of the skill it does not belong to.
--
-- The client now filters media by the card's skill path, which needs the link
-- exposed. Both RPCs already join skill_nodes for the showcase label; this adds
-- the id and path next to it. Additive: existing 'skill'/'caption' keys stay.
--
-- Then backfill the only unattributed rows in production: one real account
-- whose two uploads predate caption resolution (captions name programming
-- topics, and the taxonomy has one such skill). Mock/e2e accounts have no
-- unattributed rows, so they are excluded by the email guard.

create or replace function public.get_public_profile(
  p_user uuid,
  out p_name text,
  out p_role text,
  out p_bio text,
  out p_avatar text,
  out p_languages text,
  out p_styles text,
  out p_teaching_styles text,
  out p_availability jsonb,
  out p_teaching jsonb,
  out p_learning jsonb,
  out p_showcases jsonb
)
returns record
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  u public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into u from public.profiles where id = p_user;
  if not found then
    raise exception 'Profile not found';
  end if;

  if not coalesce(u.has_completed_onboarding, false)
     and not coalesce(auth.uid() = u.id, false)
     and not public.is_admin() then
    raise exception 'Profile not found';
  end if;

  if u.id <> auth.uid()
     and not public.is_admin()
     and public.blocked_between(auth.uid(), u.id) then
    raise exception 'Profile not found';
  end if;

  p_name := coalesce(u.display_name, '');
  p_role := u.role::text;
  p_bio := u.bio;
  p_avatar := u.avatar_url;
  p_languages := array_to_string(u.languages, ', ');
  p_styles := array_to_string(u.learning_styles, ', ');
  p_teaching_styles := array_to_string(u.teaching_styles, ', ');
  p_availability := u.availability;

  select coalesce(jsonb_agg(jsonb_build_object(
      'skill', n.name, 'path', n.path::text,
      'note', case when us.note_approved then us.note else null end
    ) order by n.name), '[]'::jsonb)
    into p_teaching
    from public.user_skills us
    join public.skill_nodes n on n.id = us.skill_id
    where us.user_id = p_user and us.kind = 'teach'::public.skill_kind;

  select coalesce(jsonb_agg(jsonb_build_object(
      'skill', n.name, 'path', n.path::text,
      'note', case when us.note_approved then us.note else null end
    ) order by n.name), '[]'::jsonb)
    into p_learning
    from public.user_skills us
    join public.skill_nodes n on n.id = us.skill_id
    where us.user_id = p_user and us.kind = 'learn'::public.skill_kind;

  select coalesce(jsonb_agg(jsonb_build_object(
      'media', sc.media_url,
      'kind', sc.media_kind::text,
      'thumb', sc.thumbnail_url,
      'skill', n.name,
      'skill_id', sc.skill_id,
      'skill_path', n.path::text,
      'caption', sc.caption
    ) order by sc.created_at), '[]'::jsonb)
    into p_showcases
    from public.skill_showcases sc
    left join public.skill_nodes n on n.id = sc.skill_id
    where sc.user_id = p_user;
end;
$$;

revoke all on function public.get_public_profile(uuid) from public, anon;
grant execute on function public.get_public_profile(uuid)
  to authenticated, service_role;

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
          'skill_id', sc.skill_id,
          'skill_path', sn.path::text,
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
    and public.side_ready(us.user_id, p_kind)
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

-- Backfill: real accounts only, matched on the caption the upload carried.
-- One row per (user, skill): uq_showcase_user_skill forbids a second showcase
-- on the same skill, so the better-matching upload takes the skill and the
-- other stays unattributed (strict scoping keeps it off cards either way).
with mapping(caption, path) as (
  values ('web development', 'modern_practical_skills.programming')
),
targets as (
  select sc.id, n.id as skill_id
  from public.skill_showcases sc
  join mapping m on lower(coalesce(sc.caption, '')) = m.caption
  join public.skill_nodes n on n.path = m.path::extensions.ltree
  where sc.skill_id is null
    and not exists (
      select 1
      from public.skill_showcases other
      where other.user_id = sc.user_id
        and other.skill_id = n.id
        and other.id <> sc.id
    )
    and exists (
      select 1
      from auth.users u
      where u.id = sc.user_id
        and u.email is not null
        and u.email not like '%@palturo.dev'
        and u.email not like '%@testmail.local'
    )
)
update public.skill_showcases sc
set skill_id = targets.skill_id
from targets
where sc.id = targets.id;
