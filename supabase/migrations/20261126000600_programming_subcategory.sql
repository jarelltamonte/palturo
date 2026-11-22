-- Programming is a generic skill that acts as a subcategory: the concrete
-- skills live under it (General Programming, Python Programming, …), the same
-- way domains hold skills one level up. Categories may contain categories, so
-- no schema change is needed; only the node kind and its children.
--
-- Order matters: the write guard refuses a kind change while a node has
-- children, so convert first, then attach.

update public.skill_nodes
set kind = 'category',
    is_general = false,
    is_leaf = false,
    updated_at = now()
where path = 'modern_practical_skills.programming'::extensions.ltree
  and kind = 'skill';

insert into public.skill_nodes
  (parent_id, name, kind, is_leaf, is_visible, origin, status,
   is_general, auto_approved, approval_source)
select p.id,
       v.name,
       'skill',
       true,
       true,
       'official',
       'approved',
       v.general,
       false,
       'manual'
from public.skill_nodes p
cross join (
  values
    ('General Programming', true),
    ('Python Programming', false)
) as v(name, general)
where p.path = 'modern_practical_skills.programming'::extensions.ltree
on conflict (path) do nothing;

-- The two skills added earlier belong under Programming, not beside it.
update public.skill_nodes
set parent_id = (
  select id from public.skill_nodes
  where path = 'modern_practical_skills.programming'::extensions.ltree
)
where path in (
  'modern_practical_skills.web_development'::extensions.ltree,
  'modern_practical_skills.c_sharp_programming'::extensions.ltree
);

-- Programming was itself selectable, so move its placement and upload to the
-- new general skill instead of orphaning them. Guarded against the per-user
-- uniqueness rules.
update public.user_skills us
set skill_id = g.id
from public.skill_nodes g
where g.path = 'modern_practical_skills.programming.general_programming'::extensions.ltree
  and us.skill_id = (
    select id from public.skill_nodes
    where path = 'modern_practical_skills.programming'::extensions.ltree
  )
  and not exists (
    select 1 from public.user_skills other
    where other.user_id = us.user_id
      and other.kind = us.kind
      and other.skill_id = g.id
  );

update public.skill_showcases sc
set skill_id = g.id
from public.skill_nodes g
where g.path = 'modern_practical_skills.programming.general_programming'::extensions.ltree
  and sc.skill_id = (
    select id from public.skill_nodes
    where path = 'modern_practical_skills.programming'::extensions.ltree
  )
  and not exists (
    select 1 from public.skill_showcases other
    where other.user_id = sc.user_id and other.skill_id = g.id
  );

-- Paths feed the profile passages, so every deck built from the old tree is
-- stale. Rebuild rather than serve a ranking that names the wrong path.
delete from public.match_cache;
delete from public.match_cache_v2;
