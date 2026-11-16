-- Media uploads failed for ordinary phone photos because every bucket stopped
-- at 5 MiB and the client refused anything larger before it even tried. Raise
-- the per-object ceilings (test cohort is small), and make skill showcases a
-- first-class row that discovery actually reads.

update storage.buckets
set file_size_limit = 20971520 -- 20 MiB
where id in ('profile-media', 'profile-photos', 'skill-proofs');

update storage.buckets
set file_size_limit = 10485760 -- 10 MiB
where id = 'avatars';

update storage.buckets
set file_size_limit = 52428800 -- 50 MiB
where id = 'skill-showcases';

-- Showcases were readable by policy but had no table grants, so the app could
-- never write the rows that discovery reads. RLS still limits writes to the
-- owner.
grant select, insert, update, delete on public.skill_showcases to authenticated;

-- Replace a user's showcases in one call so a save cannot leave a half-written
-- set. The client sends the same skill -> media map it renders in the editor.
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
  node uuid;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Showcases must be a JSON array';
  end if;

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
    caption := nullif(btrim(coalesce(item ->> 'caption', '')), '');
    node := null;
    if caption is not null then
      select id into node
      from public.skill_nodes
      where lower(name) = lower(caption)
      limit 1;
    end if;

    insert into public.skill_showcases
      (user_id, skill_id, media_url, media_kind, thumbnail_url, caption)
    values
      (me, node, media, kind, thumb, caption);
  end loop;
end;
$$;

revoke all on function public.set_skill_showcases(jsonb) from public, anon;
grant execute on function public.set_skill_showcases(jsonb) to authenticated, service_role;
