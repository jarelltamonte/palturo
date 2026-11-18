-- Normalize the legacy profile bucket column.
--
-- profiles.skill_categories predates the taxonomy rework: it still holds
-- retired bucket slugs (everyday_skills, language_culture, arts_design) and
-- sometimes depth-2 skill slugs. Only the search vector reads it now, so
-- recompute it from the user's actual skill taxonomy roots. New saves write
-- the same shape through resolveCategoriesForSkills.

update public.profiles p
set skill_categories = coalesce(sub.roots, '{}'::text[])
from (
  select
    us.user_id,
    array_agg(distinct root.path::text order by root.path::text) as roots
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.skill_nodes root
    on root.kind = 'category'
   and root.depth = 1
   and root.path @> n.path
  group by us.user_id
) sub
where p.id = sub.user_id
  and coalesce(p.skill_categories, '{}'::text[])
      is distinct from coalesce(sub.roots, '{}'::text[]);

-- Profiles with no skills should not keep a stale bucket.
update public.profiles p
set skill_categories = '{}'::text[]
where coalesce(array_length(p.skill_categories, 1), 0) > 0
  and not exists (
    select 1 from public.user_skills us where us.user_id = p.id
  );
