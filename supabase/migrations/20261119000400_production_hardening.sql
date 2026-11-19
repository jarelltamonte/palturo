-- Production hardening from the pre-release audit.
--
-- 1. Pair-scoped cache invalidation for reports/connections/blocks.
-- 2. Showcase cache invalidation is row-scoped and capped, not a global wipe.
-- 3. Presence is visible only to accepted Pals.
-- 4. Pending/rejected taxonomy rows are not readable by other users.
-- 5. get_public_profile requires an authenticated caller.
-- 6. Direct showcase writes must use trusted media and respect a row cap.
-- 7. Missing indexes used by discovery and cache cleanup.
-- 8. Storage write policies are versioned with the app.

-- ---------------------------------------------------------------------------
-- 1. Pair-scoped match cache invalidation
-- ---------------------------------------------------------------------------
create or replace function public.invalidate_pair_match_cache(
  p_a uuid,
  p_b uuid
)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.match_cache
  where (user_id = p_a and candidate_id = p_b)
     or (user_id = p_b and candidate_id = p_a);
$$;

revoke all on function public.invalidate_pair_match_cache(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.invalidate_pair_match_cache(uuid, uuid)
  to service_role;

create or replace function public.invalidate_connection_match_cache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.invalidate_pair_match_cache(
    coalesce(new.requester_id, old.requester_id),
    coalesce(new.recipient_id, old.recipient_id)
  );
  return null;
end;
$$;

drop trigger if exists invalidate_connection_match_cache on public.connections;
create trigger invalidate_connection_match_cache
  after insert or update or delete on public.connections
  for each row execute function public.invalidate_connection_match_cache();

create or replace function public.invalidate_report_match_cache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.invalidate_pair_match_cache(
    coalesce(new.reporter_id, old.reporter_id),
    coalesce(new.reported_id, old.reported_id)
  );
  return null;
end;
$$;

drop trigger if exists invalidate_report_match_cache on public.reports;
create trigger invalidate_report_match_cache
  after insert or update or delete on public.reports
  for each row execute function public.invalidate_report_match_cache();

create or replace function public.invalidate_block_match_cache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.invalidate_pair_match_cache(
    coalesce(new.blocker_id, old.blocker_id),
    coalesce(new.blocked_id, old.blocked_id)
  );
  return null;
end;
$$;

drop trigger if exists invalidate_block_match_cache on public.blocks;
create trigger invalidate_block_match_cache
  after insert or update or delete on public.blocks
  for each row execute function public.invalidate_block_match_cache();

-- ---------------------------------------------------------------------------
-- 2. Row-scoped showcase/media invalidation
-- ---------------------------------------------------------------------------
create or replace function public.invalidate_showcase_match_cache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := coalesce(new.user_id, old.user_id);
begin
  if uid is null then
    return null;
  end if;
  delete from public.match_cache
  where user_id = uid or candidate_id = uid;
  return null;
end;
$$;

drop trigger if exists invalidate_showcase_match_cache on public.skill_showcases;
create trigger invalidate_showcase_match_cache
  after insert or update or delete on public.skill_showcases
  for each row execute function public.invalidate_showcase_match_cache();

create or replace function public.invalidate_profile_media_match_cache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.match_cache
  where user_id = new.id or candidate_id = new.id;
  return null;
end;
$$;

drop trigger if exists invalidate_profile_media_match_cache on public.profiles;
create trigger invalidate_profile_media_match_cache
  after update of teaching_skill_images on public.profiles
  for each row execute function public.invalidate_profile_media_match_cache();

-- Keep the legacy function for any old caller, but stop using it from triggers.
create or replace function public.invalidate_all_match_cache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.match_cache where true;
  return null;
end;
$$;

-- Cap and rate-limit showcase writes. set_skill_showcases deletes first, so a
-- normal replace still works at the cap.
create or replace function public.set_skill_showcases(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  item jsonb;
  media text;
  kind public.media_kind;
  thumb text;
  caption text;
  skill_label text;
  node uuid;
  old_captions jsonb := '{}'::jsonb;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Showcases must be a JSON array';
  end if;
  if jsonb_array_length(p_items) > 12 then
    raise exception 'Too many showcases';
  end if;
  if not public.consume_rate_limit(me, 'set_skill_showcases', 60, 3600) then
    raise exception 'Too many showcase updates';
  end if;

  select coalesce(jsonb_object_agg(s.media_url, s.caption), '{}'::jsonb)
    into old_captions
  from public.skill_showcases s
  where s.user_id = me and s.caption is not null;

  delete from public.skill_showcases where user_id = me;

  for item in select * from jsonb_array_elements(p_items) loop
    media := btrim(coalesce(item ->> 'media_url', ''));
    if media = '' then
      continue;
    end if;
    if not public.is_trusted_https_url(media) then
      raise exception 'Showcase media must use the project storage origin';
    end if;

    kind := coalesce(
      nullif(btrim(coalesce(item ->> 'media_kind', '')), '')::public.media_kind,
      'image'::public.media_kind
    );
    thumb := nullif(btrim(coalesce(item ->> 'thumbnail_url', '')), '');
    skill_label := nullif(btrim(coalesce(item ->> 'caption', '')), '');
    caption := skill_label;

    if old_captions ? media then
      caption := coalesce(old_captions ->> media, caption);
    end if;

    node := public.resolve_skill_node(skill_label);

    insert into public.skill_showcases
      (user_id, skill_id, media_url, media_kind, thumbnail_url, caption)
    values
      (me, node, media, kind, thumb, caption);
  end loop;
end;
$$;

revoke all on function public.set_skill_showcases(jsonb) from public, anon;
grant execute on function public.set_skill_showcases(jsonb)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Presence is Pals-only
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated can read visible presence" on public.profile_presence;
create policy "Accepted Pals can read visible presence"
  on public.profile_presence
  for select
  to authenticated
  using (
    presence_enabled
    and exists (
      select 1
      from public.connections c
      where c.status = 'accepted'
        and (
          (c.requester_id = auth.uid() and c.recipient_id = profile_presence.user_id)
          or (c.recipient_id = auth.uid() and c.requester_id = profile_presence.user_id)
        )
    )
  );

-- ---------------------------------------------------------------------------
-- 4. Taxonomy rows are approved or the caller's own submission
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated can read skill taxonomy" on public.skill_nodes;
create policy "Authenticated can read approved or own taxonomy"
  on public.skill_nodes
  for select
  to authenticated
  using (status = 'approved' or submitted_by = auth.uid());

-- ---------------------------------------------------------------------------
-- 5. Public profile requires authentication
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 6. Direct showcase writes must be trusted and bounded
-- ---------------------------------------------------------------------------
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
  if not public.is_trusted_https_url(media) then
    raise exception 'Showcase media must use the project storage origin';
  end if;
  if thumb is not null and not public.is_trusted_https_url(thumb) then
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

create or replace function public.limit_skill_showcases()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*)
    from public.skill_showcases
    where user_id = new.user_id
  ) >= 12 then
    raise exception 'Showcase limit reached';
  end if;
  return new;
end;
$$;

drop trigger if exists limit_skill_showcases on public.skill_showcases;
create trigger limit_skill_showcases
  before insert on public.skill_showcases
  for each row execute function public.limit_skill_showcases();

-- ---------------------------------------------------------------------------
-- 7. Indexes used by discovery and cache cleanup
-- ---------------------------------------------------------------------------
create index if not exists idx_reports_reporter
  on public.reports (reporter_id);
create index if not exists idx_reports_reported
  on public.reports (reported_id);
create index if not exists idx_match_cache_candidate
  on public.match_cache (candidate_id);
create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 8. Storage write policies (public buckets, owner-folder writes)
-- ---------------------------------------------------------------------------
drop policy if exists "Owners write profile media" on storage.objects;
create policy "Owners write profile media"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners update profile media" on storage.objects;
create policy "Owners update profile media"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners delete profile media" on storage.objects;
create policy "Owners delete profile media"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners write skill showcases" on storage.objects;
create policy "Owners write skill showcases"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'skill-showcases'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners update skill showcases" on storage.objects;
create policy "Owners update skill showcases"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'skill-showcases'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'skill-showcases'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners delete skill showcases" on storage.objects;
create policy "Owners delete skill showcases"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'skill-showcases'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners write profile photos" on storage.objects;
create policy "Owners write profile photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners update profile photos" on storage.objects;
create policy "Owners update profile photos"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners delete profile photos" on storage.objects;
create policy "Owners delete profile photos"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners write avatars" on storage.objects;
create policy "Owners write avatars"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners update avatars" on storage.objects;
create policy "Owners update avatars"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners delete avatars" on storage.objects;
create policy "Owners delete avatars"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
