-- build_profile_passages() was written against a session search_path that
-- includes the extensions schema. The possible-match worker deliberately runs
-- with a narrow search_path, so the ltree ancestry operator must be explicit
-- rather than relying on the caller. Behavior is unchanged.

create or replace function public.build_profile_passages(p_user uuid)
returns table (
  role public.embed_role,
  field_group public.embed_field_group,
  source_text text,
  source_hash text
)
language sql
stable
as $$
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
     from public.skill_nodes a
     where a.path operator(extensions.@>) d.path)
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
    case when a.days <> '' then '; Available: ' || a.days || ' (' || coalesce(p.timezone,'Asia/Manila') || ')' else '' end || '.'
  from public.profiles p join avail a on a.pid = p.id
  where p.id = p_user
  union all
  select 'learner'::public.embed_role, 'context'::public.embed_field_group,
    'Learning preferences. Languages: ' || coalesce(array_to_string(p.languages, ', '),'') ||
    case when coalesce(array_length(p.learning_styles,1),0) > 0
      then '; Learning styles: ' || array_to_string(p.learning_styles, ', ') else '' end ||
    case when a.days <> '' then '; Available: ' || a.days || ' (' || coalesce(p.timezone,'Asia/Manila') || ')' else '' end || '.'
  from public.profiles p join avail a on a.pid = p.id
  where p.id = p_user
) r
where r.txt is not null and btrim(r.txt) <> '';
$$;
