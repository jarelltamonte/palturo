-- Two programming skills were submitted but never created: the classifier had
-- no parent to place them under, so the names only survived in
-- profiles.teaching_skills and their uploads stayed unattributed.
--
-- They are distinct skills (not focuses of Programming), so they sit under the
-- Modern Practical Skills category. Slugs follow the classifier's normalize():
-- non-alphanumerics collapse to "_", so "C#" becomes "c_programming".

insert into public.skill_nodes
  (parent_id, name, path, depth, is_leaf, is_visible, origin, status, kind,
   is_general, auto_approved, approval_source)
select p.id,
       v.name,
       (p.path::text || '.' || v.slug)::extensions.ltree,
       p.depth + 1,
       true,
       true,
       'official',
       'approved',
       'skill',
       false,
       false,
       'manual'
from public.skill_nodes p
cross join (
  values
    ('Web Development', 'web_development'),
    ('C# Programming', 'c_programming')
) as v(name, slug)
where p.path = 'modern_practical_skills'::extensions.ltree
on conflict (path) do nothing;

-- Point every upload that carries one of these captions at the new node.
-- Distinct skills, so the one-showcase-per-skill rule still holds.
update public.skill_showcases sc
set skill_id = n.id
from public.skill_nodes n
where n.name = 'Web Development'
  and n.kind = 'skill'
  and n.path <@ 'modern_practical_skills'::extensions.ltree
  and lower(coalesce(sc.caption, '')) = 'web development';

update public.skill_showcases sc
set skill_id = n.id
from public.skill_nodes n
where n.name = 'C# Programming'
  and n.kind = 'skill'
  and n.path <@ 'modern_practical_skills'::extensions.ltree
  and lower(coalesce(sc.caption, '')) = 'c# programming';

