-- Skill taxonomy roles: category / skill / focus.
--
-- Selectability stops being a depth convention. A node is selectable only when
-- kind = 'skill'; categories group, focus nodes refine a skill. Depth becomes
-- a consequence of tree position, so a skill may live at depth 2, 3, or deeper.
--
-- This migration also re-levels the Programming branch:
--   Modern Practical Skills > Programming (category) > General/Python/C#/Web
-- and moves the existing Programming attachments to General Programming.

-- 1. Role columns -----------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_type where typname = 'skill_node_kind') then
    create type public.skill_node_kind as enum ('category', 'skill', 'focus');
  end if;
end
$$;

alter table public.skill_nodes
  add column if not exists kind public.skill_node_kind,
  add column if not exists is_general boolean not null default false;

update public.skill_nodes
set kind = case
  when depth <= 1 then 'category'::public.skill_node_kind
  when depth = 2 then 'skill'::public.skill_node_kind
  else 'focus'::public.skill_node_kind
end
where kind is null;

alter table public.skill_nodes alter column kind set not null;

alter table public.skill_nodes drop constraint if exists skill_nodes_general_skill_check;
alter table public.skill_nodes
  add constraint skill_nodes_general_skill_check
  check (not is_general or kind = 'skill');

-- 2. Helpers and existing guards --------------------------------------------

create or replace function public.skill_node_slug(p_name text)
returns text
language sql
immutable
as $$
  select trim(both '_' from regexp_replace(
    regexp_replace(
      regexp_replace(lower(btrim(coalesce(p_name, ''))), '[#]', '_sharp', 'g'),
      '[+]', '_plus', 'g'
    ),
    '[^a-z0-9]+', '_', 'g'
  ));
$$;

-- The old guard allowed only depth <= 2. Selection is now role-based.
create or replace function public.enforce_leaf_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_kind public.skill_node_kind;
begin
  select kind into v_kind from public.skill_nodes where id = new.skill_id;
  if v_kind is null or v_kind <> 'skill' then
    raise exception 'Only skill nodes can be declared';
  end if;
  return new;
end
$function$;

-- Keep usage counts correct when an attachment moves between nodes.
create or replace function public.update_node_usage()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  sid uuid;
begin
  if tg_op = 'UPDATE' and new.skill_id is distinct from old.skill_id then
    update public.skill_nodes s set usage_count =
      (select count(*) from public.user_skills us where us.skill_id = old.skill_id)
    where s.id = old.skill_id;
  end if;

  sid := coalesce(new.skill_id, old.skill_id);
  update public.skill_nodes s set usage_count =
    (select count(*) from public.user_skills us where us.skill_id = sid)
  where s.id = sid;
  return null;
end
$function$;

-- 3. Re-level the Programming branch ---------------------------------------

do $$
declare
  v_prog uuid;
  v_general uuid;
begin
  select id into v_prog
  from public.skill_nodes
  where path::text = 'modern_practical_skills.programming';

  if v_prog is null then
    return;
  end if;

  if exists (
    select 1 from public.skill_nodes
    where path::text = 'modern_practical_skills.programming.general_programming'
  ) then
    return;
  end if;

  insert into public.skill_nodes
    (parent_id, name, path, depth, is_leaf, is_visible, origin, status, kind, is_general, usage_count)
  values
    (v_prog, 'General Programming',
     'modern_practical_skills.programming.general_programming'::extensions.ltree,
     3, true, true, 'official', 'approved', 'skill', true, 0)
  returning id into v_general;

  update public.user_skills
  set skill_id = v_general, updated_at = now()
  where skill_id = v_prog;

  update public.skill_nodes
  set kind = 'category', is_leaf = false, is_general = false, usage_count = 0, updated_at = now()
  where id = v_prog;

  insert into public.skill_nodes
    (parent_id, name, path, depth, is_leaf, is_visible, origin, status, kind, is_general, usage_count)
  values
    (v_prog, 'Python Programming',
     'modern_practical_skills.programming.python_programming'::extensions.ltree,
     3, true, true, 'official', 'approved', 'skill', false, 0),
    (v_prog, 'C# Programming',
     'modern_practical_skills.programming.c_sharp_programming'::extensions.ltree,
     3, true, true, 'official', 'approved', 'skill', false, 0),
    (v_prog, 'Web Development',
     'modern_practical_skills.programming.web_development'::extensions.ltree,
     3, true, true, 'official', 'approved', 'skill', false, 0);
end
$$;

-- Rebuild the denormalized name arrays from the source of truth.
update public.profiles p
set learning_skills = coalesce((
      select array_agg(distinct n.name order by n.name)
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.user_id = p.id and us.kind = 'learn'
    ), '{}'::text[]),
    teaching_skills = coalesce((
      select array_agg(distinct n.name order by n.name)
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.user_id = p.id and us.kind = 'teach'
    ), '{}'::text[]);

-- 4. Invalidate embeddings and cached rankings for the moved users ----------

create temp table _taxonomy_affected on commit drop as
select distinct us.user_id
from public.user_skills us
join public.skill_nodes n on n.id = us.skill_id
where n.path::text like 'modern_practical_skills.programming%';

delete from public.profile_embeddings
where user_id in (select user_id from _taxonomy_affected);

delete from public.match_cache
where user_id in (select user_id from _taxonomy_affected)
   or candidate_id in (select user_id from _taxonomy_affected);

update public.pipeline_config
set value = to_jsonb(((value #>> '{}')::int + 1))
where key = '__revision';

-- 5. Structural guards ------------------------------------------------------

create or replace function public.skill_node_write_guard()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  v_parent_kind public.skill_node_kind;
  v_parent_path extensions.ltree;
  v_parent_depth smallint;
  v_slug text;
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
    v_slug := public.skill_node_slug(new.name);
    new.path := v_slug::extensions.ltree;
    new.depth := 1;
  else
    if new.parent_id = new.id then
      raise exception 'A skill node cannot be its own parent';
    end if;

    select kind, path, depth into v_parent_kind, v_parent_path, v_parent_depth
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

    v_slug := public.skill_node_slug(new.name);
    new.path := (v_parent_path || v_slug::extensions.ltree);
    new.depth := v_parent_depth + 1;
  end if;

  if new.is_general and new.kind <> 'skill' then
    raise exception 'Only skills can be marked general';
  end if;

  return new;
end
$function$;

drop trigger if exists trg_skill_node_write_guard on public.skill_nodes;
create trigger trg_skill_node_write_guard
  before insert or update on public.skill_nodes
  for each row
  execute function public.skill_node_write_guard();

create or replace function public.user_skill_write_guard()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  v_kind public.skill_node_kind;
  v_skill_path extensions.ltree;
  v_focus_kind public.skill_node_kind;
  v_focus_path extensions.ltree;
begin
  select kind, path into v_kind, v_skill_path
  from public.skill_nodes where id = new.skill_id;
  if not found or v_kind <> 'skill' then
    raise exception 'skill_id must reference a skill node';
  end if;

  if new.focus_skill_id is not null then
    select kind, path into v_focus_kind, v_focus_path
    from public.skill_nodes where id = new.focus_skill_id;
    if not found or v_focus_kind <> 'focus' then
      raise exception 'focus_skill_id must reference a focus node';
    end if;
    if not (v_focus_path <@ v_skill_path) then
      raise exception 'The focus must belong to the selected skill';
    end if;
  end if;

  return new;
end
$function$;

drop trigger if exists trg_user_skill_write_guard on public.user_skills;
create trigger trg_user_skill_write_guard
  before insert or update of skill_id, focus_skill_id on public.user_skills
  for each row
  execute function public.user_skill_write_guard();

create unique index if not exists skill_nodes_parent_name_unique
  on public.skill_nodes (parent_id, lower(name))
  where status <> 'rejected';

create unique index if not exists skill_nodes_one_general
  on public.skill_nodes ((coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)))
  where is_general and kind = 'skill';

-- 6. Resolvers --------------------------------------------------------------

create or replace function public.resolve_skill_node(p_name text)
returns uuid
language plpgsql
stable
as $function$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_id uuid;
  v_slug text;
  v_tokens text[];
begin
  if v_name = '' then
    return null;
  end if;

  -- exact skill name
  select n.id into v_id
  from public.skill_nodes n
  where n.kind = 'skill'
    and (n.status = 'approved' or n.submitted_by = auth.uid())
    and lower(n.name) = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then return v_id; end if;

  -- exact skill path
  select n.id into v_id
  from public.skill_nodes n
  where n.kind = 'skill'
    and (n.status = 'approved' or n.submitted_by = auth.uid())
    and n.path::text = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then return v_id; end if;

  -- skill slug
  v_slug := public.skill_node_slug(v_name);
  if v_slug <> '' then
    select n.id into v_id
    from public.skill_nodes n
    where n.kind = 'skill'
      and (n.status = 'approved' or n.submitted_by = auth.uid())
      and split_part(n.path::text, '.', -1) = v_slug
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
    if v_id is not null then return v_id; end if;
  end if;

  -- focus name/path/slug maps to the parent skill
  select parent.id into v_id
  from public.skill_nodes n
  join public.skill_nodes parent on parent.id = n.parent_id
  where n.kind = 'focus'
    and parent.kind = 'skill'
    and (n.status = 'approved' or n.submitted_by = auth.uid())
    and (
      lower(n.name) = lower(v_name)
      or n.path::text = lower(v_name)
      or (v_slug <> '' and split_part(n.path::text, '.', -1) = v_slug)
    )
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then return v_id; end if;

  -- a category name maps to its general skill, when one exists
  select child.id into v_id
  from public.skill_nodes c
  join public.skill_nodes child
    on child.parent_id = c.id
   and child.kind = 'skill'
   and child.is_general
  where c.kind = 'category'
    and (c.status = 'approved' or c.submitted_by = auth.uid())
    and (
      lower(c.name) = lower(v_name)
      or c.path::text = lower(v_name)
      or (v_slug <> '' and split_part(c.path::text, '.', -1) = v_slug)
    )
    and (child.status = 'approved' or child.submitted_by = auth.uid())
  order by (child.status = 'approved') desc, child.usage_count desc
  limit 1;
  if v_id is not null then return v_id; end if;

  -- token match among skills, then among focus -> parent
  select array_agg(t order by t) into v_tokens
  from unnest(regexp_split_to_array(lower(v_name), '[^a-z0-9]+')) t
  where t <> '';
  if v_tokens is not null then
    select n.id into v_id
    from public.skill_nodes n
    where n.kind = 'skill'
      and (n.status = 'approved' or n.submitted_by = auth.uid())
      and (
        select array_agg(t order by t)
        from unnest(regexp_split_to_array(lower(n.name), '[^a-z0-9]+')) t
        where t <> ''
      ) = v_tokens
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
    if v_id is not null then return v_id; end if;

    select parent.id into v_id
    from public.skill_nodes n
    join public.skill_nodes parent on parent.id = n.parent_id
    where n.kind = 'focus'
      and parent.kind = 'skill'
      and (n.status = 'approved' or n.submitted_by = auth.uid())
      and (
        select array_agg(t order by t)
        from unnest(regexp_split_to_array(lower(n.name), '[^a-z0-9]+')) t
        where t <> ''
      ) = v_tokens
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
  end if;

  return v_id;
end
$function$;

create or replace function public.resolve_skill_focus(p_name text)
returns uuid
language plpgsql
stable
as $function$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_id uuid;
  v_slug text;
  v_tokens text[];
begin
  if v_name = '' then
    return null;
  end if;

  v_slug := public.skill_node_slug(v_name);
  select n.id into v_id
  from public.skill_nodes n
  where n.kind = 'focus'
    and (n.status = 'approved' or n.submitted_by = auth.uid())
    and (
      lower(n.name) = lower(v_name)
      or n.path::text = lower(v_name)
      or (v_slug <> '' and split_part(n.path::text, '.', -1) = v_slug)
    )
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then return v_id; end if;

  select array_agg(t order by t) into v_tokens
  from unnest(regexp_split_to_array(lower(v_name), '[^a-z0-9]+')) t
  where t <> '';
  if v_tokens is not null then
    select n.id into v_id
    from public.skill_nodes n
    where n.kind = 'focus'
      and (n.status = 'approved' or n.submitted_by = auth.uid())
      and (
        select array_agg(t order by t)
        from unnest(regexp_split_to_array(lower(n.name), '[^a-z0-9]+')) t
        where t <> ''
      ) = v_tokens
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
  end if;

  return v_id;
end
$function$;

-- Keep the stored focus attached to the skill it belongs to.
create or replace function public.save_user_skills(
  p_learning jsonb default null,
  p_teaching jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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

      -- A focus only sticks when it is under the resolved skill.
      if not exists (
        select 1
        from public.skill_nodes f
        join public.skill_nodes s on s.id = v_node
        where f.id = v_focus and f.path <@ s.path
      ) then
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
$function$;

-- 7. Read paths -------------------------------------------------------------

drop function if exists public.taxonomy_visible(text);

create function public.taxonomy_visible(p_root_path text default null)
returns table (
  id uuid,
  name text,
  path text,
  depth smallint,
  is_leaf boolean,
  usage_count integer,
  kind text,
  is_general boolean
)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
  select n.id, n.name, n.path::text, n.depth, n.is_leaf, n.usage_count,
         n.kind::text, n.is_general
  from public.skill_nodes n
  where n.status <> 'rejected'
    and (n.status = 'approved' or n.submitted_by = auth.uid())
    and (p_root_path is null or p_root_path::extensions.ltree @> n.path)
  order by n.path;
$function$;

revoke all on function public.taxonomy_visible(text) from public, anon;
grant execute on function public.taxonomy_visible(text) to authenticated, service_role;

create or replace function public.browse_skill_users(
  p_node text,
  p_kind public.skill_kind default 'teach',
  p_limit integer default 50
)
returns table (
  user_id uuid,
  name text,
  role text,
  avatar_url text,
  note text,
  availability jsonb,
  languages text[],
  learning_styles text[],
  teaching_styles text[],
  skill_name text,
  skill_path text,
  showcases jsonb
)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
  select distinct on (us.user_id)
    us.user_id,
    coalesce(p.display_name, ''),
    p.role::text,
    p.avatar_url,
    case when us.note_approved then us.note else null end,
    coalesce(p.availability, '{}'::jsonb),
    coalesce(p.languages, '{}'::text[]),
    coalesce(p.learning_styles, '{}'::text[]),
    coalesce(p.teaching_styles, '{}'::text[]),
    n.name,
    n.path::text,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'media', sc.media_url,
          'kind', sc.media_kind::text,
          'thumb', sc.thumbnail_url,
          'skill', sn.name,
          'caption', sc.caption
        )
        order by sc.created_at
      )
      from public.skill_showcases sc
      left join public.skill_nodes sn on sn.id = sc.skill_id
      where sc.user_id = us.user_id
    ), '[]'::jsonb)
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  where (p_node::extensions.ltree @> n.path)
    and n.kind = 'skill'
    and us.kind = p_kind
    and n.status = 'approved'
    and p.has_completed_onboarding
    and public.has_discovery_media(p.id)
    and (auth.uid() is null or us.user_id <> auth.uid())
    and not exists (
      select 1
      from public.blocks b
      where auth.uid() is not null
        and ((b.blocker_id = auth.uid() and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = auth.uid()))
    )
    and not exists (
      select 1
      from public.connections c
      where auth.uid() is not null
        and ((c.requester_id = auth.uid() and c.recipient_id = us.user_id)
          or (c.requester_id = us.user_id and c.recipient_id = auth.uid()))
    )
  order by us.user_id, n.usage_count desc, n.name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$function$;

create or replace function public.build_profile_passages(p_user uuid)
returns table (role embed_role, field_group embed_field_group, source_text text, source_hash text)
language sql
stable
as $function$
with declared as (
  select us.kind,
    case when us.note_approved then us.note else null end as note,
    node.path, node.name,
    focus.name as focus_name
  from public.user_skills us
  join public.skill_nodes node
    on node.id = us.skill_id
   and node.kind = 'skill'
   and node.status = 'approved'
  left join public.skill_nodes focus
    on focus.id = us.focus_skill_id
   and focus.kind = 'focus'
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
    case when coalesce(array_length(p.teaching_styles,1),0) > 0
      then '; Teaching styles: ' || array_to_string(p.teaching_styles, ', ') else '' end ||
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

create or replace function public.match_candidates(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real
)
returns table (candidate_id uuid, bi_score real)
language sql
stable
security definer
set search_path = 'public'
as $function$
with seeker as (
  select (case when p_target = 'mentor' then 'learner' else 'mentor' end)::public.embed_role as s_role
),
target_kind as (
  select (case when p_target = 'mentor' then 'teach' else 'learn' end)::public.skill_kind as k
),
blocked as (
  select blocked_id as uid from public.blocks where blocker_id = p_user
  union
  select blocker_id as uid from public.blocks where blocked_id = p_user
),
connected as (
  select case when c.requester_id = p_user then c.recipient_id else c.requester_id end as uid
  from public.connections c
  where c.requester_id = p_user or c.recipient_id = p_user
),
s_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'skills'::public.embed_field_group
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
),
s_sc as (
  select e.user_id, (1 - extensions.cosine_distance(s_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join s_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'skills'::public.embed_field_group
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
    and not exists (select 1 from connected cn where cn.uid = e.user_id)
),
c_sc as (
  select e.user_id, (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'context'::public.embed_field_group
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
    and not exists (select 1 from connected cn where cn.uid = e.user_id)
),
fallback as (
  select distinct us.user_id
  from public.user_skills us
  cross join target_kind tk
  join public.skill_nodes n
    on n.id = us.skill_id
   and n.kind = 'skill'
   and n.status = 'approved'
  join public.profiles pf on pf.id = us.user_id and pf.has_completed_onboarding
  where us.kind = tk.k
    and us.user_id <> p_user
    and public.has_discovery_media(us.user_id)
    and not exists (select 1 from blocked b where b.uid = us.user_id)
    and not exists (select 1 from connected cn where cn.uid = us.user_id)
  limit 200
),
u as (
  select user_id from s_sc
  union
  select user_id from c_sc
  union
  select user_id from fallback
)
select u.user_id,
  (p_w_skills * coalesce(s_sc.sim, 0) + p_w_context * coalesce(c_sc.sim, 0))::real
from u
left join s_sc on s_sc.user_id = u.user_id
left join c_sc on c_sc.user_id = u.user_id
join public.profiles pf on pf.id = u.user_id and pf.has_completed_onboarding
where not exists (select 1 from blocked b where b.uid = u.user_id)
  and not exists (select 1 from connected cn where cn.uid = u.user_id)
  and public.has_discovery_media(u.user_id)
  and (
    coalesce(auth.role(), '') = 'service_role'
    or p_user = auth.uid()
  )
order by 2 desc
limit p_limit;
$function$;

