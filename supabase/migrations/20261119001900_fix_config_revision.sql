-- Atomic config publishing must advance __revision exactly once, not once per
-- key. The existing row trigger bumps the counter on every pipeline_config
-- write, so publishing suppressed it during the full replacement and writes
-- the revision explicitly.

create or replace function public.bump_config_revision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('palturo.suppress_revision', true) = 'on' then
    return null;
  end if;
  if tg_op = 'DELETE' then
    if old.key = '__revision' then return null; end if;
  else
    if new.key = '__revision' then return null; end if;
  end if;
  insert into public.pipeline_config (key, value, description)
    values ('__revision', to_jsonb(1), 'internal revision counter (do not edit)')
    on conflict (key) do update
      set value = to_jsonb(((public.pipeline_config.value #>> '{}')::int) + 1),
          updated_at = now();
  return null;
end;
$$;

create or replace function public.admin_publish_config(
  p_config jsonb,
  p_actor uuid,
  p_reason text,
  p_version_id uuid default null,
  p_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
  v_value jsonb;
  v_revision integer := 0;
  v_version uuid := p_version_id;
begin
  if p_config is null or jsonb_typeof(p_config) <> 'object' then
    raise exception 'Config must be a JSON object';
  end if;
  if length(coalesce(trim(p_reason), '')) < 3 then
    raise exception 'A reason of at least 3 characters is required';
  end if;
  if p_config ? '__revision' then
    raise exception '__revision is managed automatically';
  end if;
  if p_config = '{}'::jsonb then
    raise exception 'Config must not be empty';
  end if;

  -- One revision per publish, no matter how many keys change.
  perform set_config('palturo.suppress_revision', 'on', true);

  delete from public.pipeline_config
  where key <> '__revision' and not (p_config ? key);

  for v_key, v_value in select key, value from jsonb_each(p_config) loop
    insert into public.pipeline_config
      (key, value, config_version, updated_by, updated_at)
    values
      (v_key, v_value, 1, p_actor, now())
    on conflict (key) do update
      set value = excluded.value,
          updated_by = excluded.updated_by,
          updated_at = now();
  end loop;

  select coalesce((value #>> '{}')::integer, 0)
    into v_revision
  from public.pipeline_config
  where key = '__revision';
  v_revision := coalesce(v_revision, 0) + 1;

  insert into public.pipeline_config
    (key, value, config_version, updated_by, updated_at)
  values
    ('__revision', to_jsonb(v_revision), 1, p_actor, now())
  on conflict (key) do update
    set value = excluded.value,
        updated_by = excluded.updated_by,
        updated_at = now();

  perform set_config('palturo.suppress_revision', 'off', true);

  if v_version is null then
    insert into public.pipeline_config_versions
      (label, config, status, created_by, published_by, published_at, notes)
    values
      (coalesce(nullif(trim(p_label), ''),
                'Published ' || to_char(now(), 'YYYY-MM-DD HH24:MI')),
       p_config, 'published', p_actor, p_actor, now(), p_reason)
    returning id into v_version;
  else
    update public.pipeline_config_versions
    set config = p_config,
        status = 'published',
        published_by = p_actor,
        published_at = now(),
        notes = coalesce(notes, p_reason)
    where id = v_version;
    if not found then
      raise exception 'Config version not found';
    end if;
  end if;

  return jsonb_build_object(
    'revision', v_revision,
    'version_id', v_version
  );
end;
$$;

revoke all on function public.admin_publish_config(jsonb, uuid, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_publish_config(jsonb, uuid, text, uuid, text)
  to service_role;
