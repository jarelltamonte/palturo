-- Renaming a depth-2 node recomputes its own path but leaves descendants on
-- the old prefix, which breaks ltree lookups such as browse children and the
-- passage chain. Rebase each renamed subtree onto the new path.

do $$
declare
  pair record;
begin
  for pair in
    select * from (values
      ('cooking_culinary.filipino_mains', 'cooking_culinary.filipino_cooking'),
      ('cooking_culinary.filipino_desserts_kakanin', 'cooking_culinary.filipino_dessert_making'),
      ('household_skills.kitchen_skills', 'household_skills.kitchen_basics'),
      ('language_writing.philippine_scripts', 'language_writing.philippine_script_writing')
    ) as t(old_path, new_path)
  loop
    update public.skill_nodes c
    set path = (
      pair.new_path || substr(c.path::text, length(pair.old_path) + 1)
    )::extensions.ltree
    where c.path <@ pair.old_path::extensions.ltree;
  end loop;
end $$;
