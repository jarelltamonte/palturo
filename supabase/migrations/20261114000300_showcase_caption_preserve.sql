-- Showcases are keyed by the depth-2 selection in the editor, but their
-- captions can stay specific ("Cooking Pinakbet"). Preserve an existing
-- caption when the media URL is unchanged, and resolve the skill through the
-- depth-2 resolver.

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

    -- Keep the specific caption for media that was already attached.
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
grant execute on function public.set_skill_showcases(jsonb) to authenticated, service_role;
