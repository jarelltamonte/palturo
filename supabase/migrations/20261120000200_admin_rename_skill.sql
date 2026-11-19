-- Rename a skill node and rewrite descendant paths safely.
create or replace function public.admin_rename_skill(
  p_node uuid,
  p_name text,
  p_actor uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_before public.skill_nodes%rowtype;
  v_old_path extensions.ltree;
  v_new_path extensions.ltree;
  v_descendants integer := 0;
  v_name text := btrim(coalesce(p_name, ''));
begin
  if length(v_name) < 1 or length(v_name) > 80 then
    raise exception 'Name must be between 1 and 80 characters';
  end if;
  if length(coalesce(trim(p_reason), '')) < 3 then
    raise exception 'A reason of at least 3 characters is required';
  end if;

  select * into v_before from public.skill_nodes where id = p_node for update;
  if not found then
    raise exception 'Skill node not found';
  end if;
  if v_before.name = v_name then
    return jsonb_build_object('renamed', false, 'path', v_before.path::text);
  end if;

  v_old_path := v_before.path;
  perform set_config('palturo.suppress_skill_guard', 'on', true);
  update public.skill_nodes
  set name = v_name,
      updated_at = now()
  where id = p_node;

  select path into v_new_path from public.skill_nodes where id = p_node;

  update public.skill_nodes
  set path = (v_new_path::text || substring(path::text from length(v_old_path::text) + 1))::extensions.ltree,
      updated_at = now()
  where path <@ v_old_path
    and id <> p_node;
  get diagnostics v_descendants = row_count;

  perform set_config('palturo.suppress_skill_guard', 'off', true);

  insert into public.skill_change_log
    (node_id, action, before, after, reason, actor_id)
  values (
    p_node,
    'rename',
    to_jsonb(v_before),
    jsonb_build_object('name', v_name, 'path', v_new_path::text),
    p_reason,
    p_actor
  );

  return jsonb_build_object(
    'renamed', true,
    'path', v_new_path::text,
    'descendants_moved', v_descendants
  );
end;
$$;

revoke all on function public.admin_rename_skill(uuid, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_rename_skill(uuid, text, uuid, text)
  to service_role;
