-- Single owner for taxonomy paths, with a slug that survives symbols such as
-- C# and C++. The role guard keeps validation only.

create or replace function public.skill_node_path()
returns trigger
language plpgsql
as $function$
declare
  p extensions.ltree;
  d smallint;
begin
  if new.parent_id is null then
    new.path := public.skill_node_slug(new.name)::extensions.ltree;
    new.depth := 1;
  else
    select path, depth into p, d
    from public.skill_nodes where id = new.parent_id;
    if p is null then
      raise exception 'parent node not found';
    end if;
    new.path := (p::text || '.' || public.skill_node_slug(new.name))::extensions.ltree;
    new.depth := d + 1;
  end if;
  return new;
end
$function$;

create or replace function public.skill_node_write_guard()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  v_parent_kind public.skill_node_kind;
  v_parent_path extensions.ltree;
begin
  if tg_op = 'UPDATE'
     and new.name = old.name
     and new.parent_id is not distinct from old.parent_id then
    return new;
  end if;

  if new.parent_id is null then
    if new.kind <> 'category' then
      raise exception 'Only categories can be root nodes';
    end if;
  else
    if new.parent_id = new.id then
      raise exception 'A skill node cannot be its own parent';
    end if;

    select kind, path into v_parent_kind, v_parent_path
    from public.skill_nodes where id = new.parent_id;
    if not found then
      raise exception 'Parent node not found';
    end if;

    if v_parent_kind = 'category' and new.kind not in ('category', 'skill') then
      raise exception 'Categories may only contain categories or skills';
    elsif v_parent_kind = 'skill' and new.kind <> 'focus' then
      raise exception 'Skills may only contain focus nodes';
    elsif v_parent_kind = 'focus' and new.kind <> 'focus' then
      raise exception 'Focus nodes may only contain focus nodes';
    end if;

    if tg_op = 'UPDATE' and v_parent_path <@ old.path then
      raise exception 'A node cannot be moved under its own descendant';
    end if;

    if tg_op = 'UPDATE' and exists (
      select 1 from public.skill_nodes where parent_id = old.id
    ) then
      raise exception 'Move or rename a node with children through move_skill_node()';
    end if;
  end if;

  if new.is_general and new.kind <> 'skill' then
    raise exception 'Only skills can be marked general';
  end if;

  return new;
end
$function$;

-- Align the one node created before the slug helper existed.
update public.skill_nodes
set path = 'modern_practical_skills.programming.c_sharp_programming'::extensions.ltree,
    updated_at = now()
where path::text = 'modern_practical_skills.programming.c_programming';
