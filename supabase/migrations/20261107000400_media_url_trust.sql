-- Constrain profile and showcase media URLs to the project's HTTPS storage
-- origin. Previously any authenticated user could store an arbitrary http(s)
-- URL and other users' devices would fetch it (beacon/tracking and loopback
-- probing). Non-URL storage paths remain valid for private proof images.

create or replace function public.is_trusted_https_url(p_url text)
returns boolean
language sql
immutable
as $$
  select p_url is null or (
    p_url ~ '^https://yjcrfgvenilptrnudvcb\.supabase\.co/storage/v1/'
  );
$$;

create or replace function public.is_http_url(p_url text)
returns boolean
language sql
immutable
as $$
  select p_url ~* '^https?://';
$$;

create or replace function public.has_url_scheme(p_url text)
returns boolean
language sql
immutable
as $$
  select p_url ~ '^(//|[A-Za-z][A-Za-z0-9+.-]*:)';
$$;

create or replace function public.sanitize_profile_media()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.avatar_url is not null and not public.is_trusted_https_url(new.avatar_url) then
    new.avatar_url := null;
  end if;

  if new.photos is not null then
    select coalesce(array_agg(u order by ord), '{}')
      into new.photos
    from unnest(new.photos) with ordinality as t(u, ord)
    where public.is_trusted_https_url(u);
  end if;

  if new.teaching_skill_images is not null
     and jsonb_typeof(new.teaching_skill_images) = 'object' then
    select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
      into new.teaching_skill_images
    from jsonb_each(new.teaching_skill_images)
    where not public.has_url_scheme(value #>> '{}')
       or public.is_trusted_https_url(value #>> '{}');
  end if;

  return new;
end;
$$;

drop trigger if exists sanitize_profile_media on public.profiles;
create trigger sanitize_profile_media
  before insert or update of avatar_url, photos, teaching_skill_images
  on public.profiles
  for each row
  execute function public.sanitize_profile_media();

create or replace function public.validate_skill_showcase_media()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  media text := btrim(new.media_url);
  thumb text := btrim(new.thumbnail_url);
begin
  if public.has_url_scheme(media)
     and not public.is_trusted_https_url(media) then
    raise exception 'Showcase media must use the project storage origin';
  end if;
  if thumb is not null
     and public.has_url_scheme(thumb)
     and not public.is_trusted_https_url(thumb) then
    raise exception 'Showcase thumbnail must use the project storage origin';
  end if;
  new.media_url := media;
  new.thumbnail_url := thumb;
  return new;
end;
$$;

drop trigger if exists validate_skill_showcase_media on public.skill_showcases;
create trigger validate_skill_showcase_media
  before insert or update of media_url, thumbnail_url
  on public.skill_showcases
  for each row
  execute function public.validate_skill_showcase_media();

-- Clean existing rows once. Rows that only hold storage object paths are kept.
update public.profiles
set avatar_url = null
where avatar_url is not null
  and not public.is_trusted_https_url(avatar_url);

update public.profiles p
set photos = coalesce((
  select array_agg(u order by ord)
  from unnest(p.photos) with ordinality as t(u, ord)
  where public.is_trusted_https_url(u)
), '{}')
where p.photos is not null
  and exists (
    select 1 from unnest(p.photos) u
    where not public.is_trusted_https_url(u)
  );

update public.profiles p
set teaching_skill_images = coalesce((
  select jsonb_object_agg(key, value)
  from jsonb_each(p.teaching_skill_images)
  where not public.has_url_scheme(value #>> '{}')
     or public.is_trusted_https_url(value #>> '{}')
), '{}'::jsonb)
where jsonb_typeof(p.teaching_skill_images) = 'object'
  and exists (
    select 1
    from jsonb_each(p.teaching_skill_images)
    where public.has_url_scheme(value #>> '{}')
      and not public.is_trusted_https_url(value #>> '{}')
  );

-- Remove legacy showcase rows that point off-origin. Thumbnails can be nulled
-- without losing the row; a bad media_url is removed.
update public.skill_showcases
set thumbnail_url = null
where thumbnail_url is not null
  and public.has_url_scheme(thumbnail_url)
  and not public.is_trusted_https_url(thumbnail_url);

delete from public.skill_showcases
where public.has_url_scheme(media_url)
  and not public.is_trusted_https_url(media_url);

