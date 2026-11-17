-- Teaching style: the mentor counterpart of learning_styles. It is only shown
-- and edited for profiles whose role includes teaching, and it feeds the
-- mentor context passage used by matching.
--
-- Written by onboarding and the profile editor; read by the profile page,
-- the public profile dialog (get_public_profile), Browse cards
-- (browse_skill_users), and the embedding pipeline (build_profile_passages).

alter table public.profiles
  add column if not exists teaching_styles text[] not null default '{}'::text[];

-- Column-scoped grants: authenticated may read and write only this column.
grant select (teaching_styles) on public.profiles to authenticated;
grant update (teaching_styles) on public.profiles to authenticated;

-- Matching context: teach style sits next to the mentor's own learning style.
-- An empty array adds nothing, so existing passages keep their hash.
create or replace function public.build_profile_passages(p_user uuid)
returns table(role embed_role, field_group embed_field_group, source_text text, source_hash text)
language sql
stable
as $function$
with declared as (
  select us.kind,
    case when us.note_approved then us.note else null end as note,
    node.path, node.name,
    focus.name as focus_name
  from public.user_skills us
  join public.skill_nodes node on node.id = us.skill_id
  left join public.skill_nodes focus on focus.id = us.focus_skill_id
  where us.user_id = p_user
),
chains as (
  select d.kind, d.note, d.name as node_name,
    (select string_agg(a.name, ' > ' order by a.depth)
     from public.skill_nodes a where a.path @> d.path)
    || case
         when d.focus_name is not null
           then ' (focus: ' || d.focus_name || ')'
         else ''
       end as chain
  from declared d
),
avail as (
  select p.id as pid,
    coalesce(
      case jsonb_typeof(p.availability)
        when 'object' then (
          select string_agg(k, ', ')
          from jsonb_object_keys(p.availability) as k
        )
        when 'array' then (
          select string_agg(v, ', ')
          from jsonb_array_elements_text(p.availability) as v
        )
        else ''
      end,
      ''
    ) as days,
    p.timezone
  from public.profiles p where p.id = p_user
)
select r.role, r.fg, r.txt, md5(r.txt)
from (
  select 'mentor'::public.embed_role as role, 'skills'::public.embed_field_group as fg,
    'Offers to teach: ' || coalesce((
      select string_agg(c.chain || (case when c.note is not null and c.note <> '' then ' - note: ' || c.note else '' end), '; ')
      from chains c where c.kind = 'teach'), '') || '.' as txt
  union all
  select 'learner'::public.embed_role, 'skills'::public.embed_field_group,
    'Wants to learn: ' || coalesce((
      select string_agg(c.chain || (case when c.note is not null and c.note <> '' then ' - note: ' || c.note else '' end), '; ')
      from chains c where c.kind = 'learn'), '') || '.' as txt
  union all
  select 'mentor'::public.embed_role, 'context'::public.embed_field_group,
    'Teaching preferences. Languages: ' || coalesce(array_to_string(p.languages, ', '),'') ||
    case when coalesce(array_length(p.teaching_styles,1),0) > 0
      then '; Teaching styles: ' || array_to_string(p.teaching_styles, ', ') else '' end ||
    case when coalesce(array_length(p.learning_styles,1),0) > 0
      then '; Own learning styles: ' || array_to_string(p.learning_styles, ', ') else '' end ||
    case when a.days <> '' then '; Available: ' || a.days || ' (' || coalesce(a.timezone,'Asia/Manila') || ')' else '' end || '.'
  from public.profiles p join avail a on a.pid = p.id
  where p.id = p_user
  union all
  select 'learner'::public.embed_role, 'context'::public.embed_field_group,
    'Learning preferences. Languages: ' || coalesce(array_to_string(p.languages, ', '),'') ||
    case when coalesce(array_length(p.learning_styles,1),0) > 0
      then '; Learning styles: ' || array_to_string(p.learning_styles, ', ') else '' end ||
    case when a.days <> '' then '; Available: ' || a.days || ' (' || coalesce(a.timezone,'Asia/Manila') || ')' else '' end || '.'
  from public.profiles p join avail a on a.pid = p.id
  where p.id = p_user
) r
where r.txt is not null and btrim(r.txt) <> '';
$function$;

-- Adding an OUT column changes the return type, so the function is rebuilt.
drop function if exists public.get_public_profile(uuid);

create function public.get_public_profile(
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
  select * into u from public.profiles where id = p_user;
  if not found then
    raise exception 'Profile not found';
  end if;

  -- Anonymous callers only see completed profiles. The owner and admins may
  -- always see the row.
  if not coalesce(u.has_completed_onboarding, false)
     and not coalesce(auth.uid() = u.id, false)
     and not public.is_admin() then
    raise exception 'Profile not found';
  end if;

  -- Authenticated callers cannot see a profile across a block in either
  -- direction. Anonymous callers have no identity to compare.
  if auth.uid() is not null
     and u.id <> auth.uid()
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
      'caption', sc.caption
    ) order by sc.created_at), '[]'::jsonb)
    into p_showcases
    from public.skill_showcases sc
    left join public.skill_nodes n on n.id = sc.skill_id
    where sc.user_id = p_user;
end;
$$;

revoke all on function public.get_public_profile(uuid) from public;
grant execute on function public.get_public_profile(uuid) to anon, authenticated, service_role;

-- Browse cards carry the teaching style so the mentor's card can show it.
drop function if exists public.browse_skill_users(text, public.skill_kind, integer);

create function public.browse_skill_users(
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
    and not exists (
      select 1
      from public.connections c
      where auth.uid() is not null
        and ((c.requester_id = auth.uid() and c.recipient_id = us.user_id)
          or (c.requester_id = us.user_id and c.recipient_id = auth.uid()))
    )
  order by us.user_id, n.usage_count desc, n.name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

revoke all on function public.browse_skill_users(text, public.skill_kind, integer) from public, anon;
grant execute on function public.browse_skill_users(text, public.skill_kind, integer)
  to authenticated, service_role;
