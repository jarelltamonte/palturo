-- Enforce block and onboarding visibility on every profile read path.
--
-- Before this migration the authenticated SELECT policy was `using (true)`,
-- so a direct PostgREST read of profiles by a known UUID bypassed the block and
-- onboarding predicates used by browse/match. get_public_profile had the same
-- gap for anonymous callers.

create or replace function public.profile_visible(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where auth.uid() is not null
      and p.id = p_profile
      and (
        p.id = auth.uid()
        or public.is_admin()
        or (
          coalesce(p.has_completed_onboarding, false)
          and not public.blocked_between(auth.uid(), p.id)
        )
      )
  );
$$;

revoke all on function public.profile_visible(uuid) from public, anon;
grant execute on function public.profile_visible(uuid) to authenticated;

drop policy if exists "Authenticated can read profiles" on public.profiles;
drop policy if exists "Authenticated can read visible profiles" on public.profiles;
drop policy if exists "Users can read own profile" on public.profiles;

create policy "Authenticated can read visible profiles"
  on public.profiles
  for select
  to authenticated
  using (public.profile_visible(id));

create or replace function public.get_public_profile(
  p_user uuid,
  out p_name text,
  out p_role text,
  out p_bio text,
  out p_avatar text,
  out p_languages text,
  out p_styles text,
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
