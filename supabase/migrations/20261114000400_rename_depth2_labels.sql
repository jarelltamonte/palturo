-- Depth-2 labels should read as skills, not menu sections. Rename the four
-- container-like labels; paths and ids stay stable so old slugs still resolve.

with renames(old_name, new_name) as (
  values
    ('Filipino Mains', 'Filipino Cooking'),
    ('Filipino Desserts & Kakanin', 'Filipino Dessert Making'),
    ('Kitchen Skills', 'Kitchen Basics'),
    ('Philippine Scripts', 'Philippine Script Writing')
)
update public.skill_nodes n
set name = r.new_name
from renames r
where n.depth = 2 and n.name = r.old_name;

with renames(old_name, new_name) as (
  values
    ('Filipino Mains', 'Filipino Cooking'),
    ('Filipino Desserts & Kakanin', 'Filipino Dessert Making'),
    ('Kitchen Skills', 'Kitchen Basics'),
    ('Philippine Scripts', 'Philippine Script Writing')
)
update public.profiles p
set learning_skills = coalesce((
  select array_agg(distinct coalesce(r.new_name, s.name)
                   order by coalesce(r.new_name, s.name))
  from unnest(p.learning_skills) as s(name)
  left join renames r on r.old_name = s.name
), '{}'::text[])
where p.learning_skills is not null;

with renames(old_name, new_name) as (
  values
    ('Filipino Mains', 'Filipino Cooking'),
    ('Filipino Desserts & Kakanin', 'Filipino Dessert Making'),
    ('Kitchen Skills', 'Kitchen Basics'),
    ('Philippine Scripts', 'Philippine Script Writing')
)
update public.profiles p
set teaching_skills = coalesce((
  select array_agg(distinct coalesce(r.new_name, s.name)
                   order by coalesce(r.new_name, s.name))
  from unnest(p.teaching_skills) as s(name)
  left join renames r on r.old_name = s.name
), '{}'::text[])
where p.teaching_skills is not null;

with renames(old_name, new_name) as (
  values
    ('Filipino Mains', 'Filipino Cooking'),
    ('Filipino Desserts & Kakanin', 'Filipino Dessert Making'),
    ('Kitchen Skills', 'Kitchen Basics'),
    ('Philippine Scripts', 'Philippine Script Writing')
)
update public.profiles p
set teaching_skill_images = (
  select jsonb_object_agg(coalesce(r.new_name, e.key), e.value)
  from jsonb_each(p.teaching_skill_images) e
  left join renames r on r.old_name = e.key
)
where jsonb_typeof(p.teaching_skill_images) = 'object'
  and p.teaching_skill_images <> '{}'::jsonb;

-- Only captions that literally used the old container label change. Specific
-- captions such as "Cooking Pinakbet" stay.
with renames(old_name, new_name) as (
  values
    ('Filipino Mains', 'Filipino Cooking'),
    ('Filipino Desserts & Kakanin', 'Filipino Dessert Making'),
    ('Kitchen Skills', 'Kitchen Basics'),
    ('Philippine Scripts', 'Philippine Script Writing')
)
update public.skill_showcases s
set caption = r.new_name
from renames r
where s.caption = r.old_name;
