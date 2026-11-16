-- Selections move to depth 2 of the taxonomy. Depth 3 stays in the tree for
-- search aliases, showcase captions, and matching focus, but nobody is asked
-- to pick a single dish or dance step during onboarding.

-- The old guard only allowed leaves. Depth 1 and 2 are now valid selections.
create or replace function public.enforce_leaf_only()
returns trigger
language plpgsql
as $$
declare
  v_depth integer;
begin
  select depth into v_depth from public.skill_nodes where id = new.skill_id;
  if v_depth is null or v_depth > 2 then
    raise exception 'Only depth 1 or 2 skill nodes can be declared';
  end if;
  return new;
end
$$;

alter table public.user_skills
  add column if not exists focus_skill_id uuid
  references public.skill_nodes(id) on delete set null;

-- Move every existing depth-3 selection to its depth-2 parent. If the user
-- already had the parent selected, keep one row and merge the note.
do $$
declare
  r record;
  v_parent uuid;
  v_existing uuid;
begin
  for r in
    select us.id, us.user_id, us.kind, us.skill_id, us.note,
           n.parent_id
    from public.user_skills us
    join public.skill_nodes n on n.id = us.skill_id
    where n.depth > 2
    order by us.id
  loop
    v_parent := r.parent_id;
    select id into v_existing
    from public.user_skills
    where user_id = r.user_id and kind = r.kind and skill_id = v_parent
    limit 1;

    if v_existing is null then
      update public.user_skills
      set focus_skill_id = r.skill_id,
          skill_id = v_parent,
          updated_at = now()
      where id = r.id;
    else
      update public.user_skills
      set note = case
            when length(coalesce(r.note, '')) > length(coalesce(note, ''))
              then r.note
            else note
          end,
          focus_skill_id = coalesce(focus_skill_id, r.skill_id),
          updated_at = now()
      where id = v_existing;
      delete from public.user_skills where id = r.id;
    end if;
  end loop;
end $$;

-- Canonicalise the mirrored arrays. Unresolved custom names survive untouched.
update public.profiles p
set learning_skills = coalesce((
  select array_agg(distinct coalesce(parent.name, n.name)
                   order by coalesce(parent.name, n.name))
  from unnest(p.learning_skills) as s(name)
  left join public.skill_nodes n on lower(n.name) = lower(s.name)
  left join public.skill_nodes parent
    on parent.id = n.parent_id and n.depth > 2
), '{}'::text[])
where p.learning_skills is not null;

update public.profiles p
set teaching_skills = coalesce((
  select array_agg(distinct coalesce(parent.name, n.name)
                   order by coalesce(parent.name, n.name))
  from unnest(p.teaching_skills) as s(name)
  left join public.skill_nodes n on lower(n.name) = lower(s.name)
  left join public.skill_nodes parent
    on parent.id = n.parent_id and n.depth > 2
), '{}'::text[])
where p.teaching_skills is not null;

-- Showcase keys are skill names. Rename leaf keys to the parent so the editor
-- keeps showing the media after the selection layer moves up.
update public.profiles p
set teaching_skill_images = (
  select jsonb_object_agg(key, to_jsonb(value))
  from (
    select coalesce(parent.name, e.key) as key, max(e.value #>> '{}') as value
    from jsonb_each(p.teaching_skill_images) e
    left join public.skill_nodes n on lower(n.name) = lower(e.key)
    left join public.skill_nodes parent
      on parent.id = n.parent_id and n.depth > 2
    group by 1
  ) s
)
where jsonb_typeof(p.teaching_skill_images) = 'object'
  and p.teaching_skill_images <> '{}'::jsonb;

update public.skill_showcases sc
set skill_id = n.parent_id
from public.skill_nodes n
where n.id = sc.skill_id and n.depth > 2;

-- Resolution now targets the selectable layer. A leaf name still resolves,
-- but to its parent.
create or replace function public.resolve_skill_node(p_name text)
returns uuid
language plpgsql
stable
set search_path to 'public'
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_id uuid;
  v_slug text;
  v_tokens text[];
begin
  if v_name = '' then
    return null;
  end if;

  -- exact selectable name
  select n.id into v_id
  from public.skill_nodes n
  where n.depth <= 2
    and lower(n.name) = lower(v_name)
  order by n.depth desc, (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  -- exact selectable path
  select n.id into v_id
  from public.skill_nodes n
  where n.depth = 2
    and n.path::text = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  -- selectable slug
  v_slug := btrim(lower(regexp_replace(v_name, '[^a-zA-Z0-9]+', '_', 'g')), '_');
  if v_slug <> '' then
    select n.id into v_id
    from public.skill_nodes n
    where n.depth = 2
      and split_part(n.path::text, '.', -1) = v_slug
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
    if v_id is not null then
      return v_id;
    end if;
  end if;

  -- exact leaf name maps to the parent
  select parent.id into v_id
  from public.skill_nodes n
  join public.skill_nodes parent on parent.id = n.parent_id
  where n.depth > 2
    and lower(n.name) = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  -- leaf path maps to the parent
  select parent.id into v_id
  from public.skill_nodes n
  join public.skill_nodes parent on parent.id = n.parent_id
  where n.depth > 2
    and n.path::text = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  -- leaf slug maps to the parent
  if v_slug <> '' then
    select parent.id into v_id
    from public.skill_nodes n
    join public.skill_nodes parent on parent.id = n.parent_id
    where n.depth > 2
      and split_part(n.path::text, '.', -1) = v_slug
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
    if v_id is not null then
      return v_id;
    end if;
  end if;

  select array_agg(t order by t) into v_tokens
  from unnest(regexp_split_to_array(lower(v_name), '[^a-z0-9]+')) t
  where t <> '';
  if v_tokens is not null then
    select n.id into v_id
    from public.skill_nodes n
    where n.depth <= 2
      and n.status = 'approved'
      and (
        select array_agg(t order by t)
        from unnest(regexp_split_to_array(lower(n.name), '[^a-z0-9]+')) t
        where t <> ''
      ) = v_tokens
    order by n.depth desc, n.usage_count desc
    limit 1;
    if v_id is not null then
      return v_id;
    end if;

    select parent.id into v_id
    from public.skill_nodes n
    join public.skill_nodes parent on parent.id = n.parent_id
    where n.depth > 2
      and n.status = 'approved'
      and (
        select array_agg(t order by t)
        from unnest(regexp_split_to_array(lower(n.name), '[^a-z0-9]+')) t
        where t <> ''
      ) = v_tokens
    order by n.usage_count desc
    limit 1;
  end if;

  return v_id;
end;
$$;

-- The leaf a user typed or previously selected, kept only for matching.
create or replace function public.resolve_skill_focus(p_name text)
returns uuid
language plpgsql
stable
set search_path to 'public'
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_id uuid;
  v_slug text;
  v_tokens text[];
begin
  if v_name = '' then
    return null;
  end if;

  select n.id into v_id
  from public.skill_nodes n
  where n.depth > 2 and lower(n.name) = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  select n.id into v_id
  from public.skill_nodes n
  where n.depth > 2 and n.path::text = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  v_slug := btrim(lower(regexp_replace(v_name, '[^a-zA-Z0-9]+', '_', 'g')), '_');
  if v_slug <> '' then
    select n.id into v_id
    from public.skill_nodes n
    where n.depth > 2
      and split_part(n.path::text, '.', -1) = v_slug
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
    if v_id is not null then
      return v_id;
    end if;
  end if;

  select array_agg(t order by t) into v_tokens
  from unnest(regexp_split_to_array(lower(v_name), '[^a-z0-9]+')) t
  where t <> '';
  if v_tokens is not null then
    select n.id into v_id
    from public.skill_nodes n
    where n.depth > 2
      and n.status = 'approved'
      and (
        select array_agg(t order by t)
        from unnest(regexp_split_to_array(lower(n.name), '[^a-z0-9]+')) t
        where t <> ''
      ) = v_tokens
    order by n.usage_count desc
    limit 1;
  end if;

  return v_id;
end;
$$;

revoke all on function public.resolve_skill_focus(text) from public, anon, authenticated;

-- Keep the existing save logic, then attach the specific leaf when the input
-- was specific. This avoids rewriting the transactional replace routine.
alter function public.save_user_skills(jsonb, jsonb)
  rename to save_user_skills_impl;

create or replace function public.save_user_skills(
  p_learning jsonb default null,
  p_teaching jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result jsonb;
  v_uid uuid := auth.uid();
  v_kind public.skill_kind;
  v_input jsonb;
  v_rec jsonb;
  v_node uuid;
  v_focus uuid;
begin
  v_result := public.save_user_skills_impl(p_learning, p_teaching);

  if v_uid is null then
    return v_result;
  end if;

  for v_kind, v_input in
    select 'learn'::public.skill_kind, p_learning
    union all
    select 'teach'::public.skill_kind, p_teaching
  loop
    if v_input is null or jsonb_typeof(v_input) <> 'array' then
      continue;
    end if;

    for v_rec in select value from jsonb_array_elements(v_input) loop
      v_focus := public.resolve_skill_focus(v_rec ->> 'name');
      if v_focus is null then
        continue;
      end if;
      v_node := public.resolve_skill_node(v_rec ->> 'name');
      if v_node is null then
        continue;
      end if;

      update public.user_skills
      set focus_skill_id = v_focus,
          updated_at = now()
      where user_id = v_uid and skill_id = v_node and kind = v_kind;
    end loop;
  end loop;

  return v_result;
end;
$$;

revoke all on function public.save_user_skills_impl(jsonb, jsonb)
  from public, anon, authenticated;
revoke all on function public.save_user_skills(jsonb, jsonb) from public, anon;
grant execute on function public.save_user_skills(jsonb, jsonb)
  to authenticated, service_role;

-- Passages now read depth-2 selections and append the specific leaf, so the
-- embedding still carries the precision the taxonomy kept at depth 3.
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
