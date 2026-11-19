-- Matching config knobs used by get-matches, plus a transactional publish
-- helper for the admin panel.
--
-- Defaults reproduce the previously hardcoded matcher behavior exactly, so
-- publishing an unchanged config is a no-op for rankings.

insert into public.pipeline_config (key, value, description, config_version)
values
  ('rerank_a_weight', to_jsonb(0.6),
   'Weight of direction A when reciprocal_formula = weighted_mean', 1),
  ('rerank_b_weight', to_jsonb(0.4),
   'Weight of direction B when reciprocal_formula = weighted_mean', 1),
  ('rerank_b_limit', to_jsonb(10),
   'Only rerank direction B for the strongest N direction-A candidates', 1),
  ('rerank_b_concurrency', to_jsonb(10),
   'Parallel direction-B rerank calls', 1),
  ('rerank_budget_ms', to_jsonb(9000),
   'Total direction-B rerank budget per deck request', 1),
  ('rerank_a_timeout_ms', to_jsonb(7000),
   'Single batched direction-A rerank timeout', 1),
  ('rerank_b_timeout_ms', to_jsonb(4000),
   'Per-call direction-B rerank timeout', 1),
  ('get_matches_rate_limit', to_jsonb(60),
   'get-matches calls allowed per user per window', 1),
  ('get_matches_rate_window_seconds', to_jsonb(3600),
   'get-matches rate-limit window in seconds', 1),
  ('max_deck_size', to_jsonb(20),
   'Maximum cards returned and cached per role deck', 1)
on conflict (key) do nothing;

update public.pipeline_config
set description = 'sqrt(a*b), arithmetic_mean, weighted_mean, harmonic_mean, or min'
where key = 'reciprocal_formula'
  and (description is null or description not like '%arithmetic_mean%');

-- Publish a complete config atomically. Keys missing from p_config are
-- removed (except the managed __revision). A version row is created when no
-- version id is supplied, so every publish is traceable and reversible.
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
  if jsonb_typeof(p_config) = 'object' and p_config = '{}'::jsonb then
    raise exception 'Config must not be empty';
  end if;

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
