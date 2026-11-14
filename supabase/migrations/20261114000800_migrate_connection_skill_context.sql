-- Requests created before the depth-2 move still carry a leaf skill context,
-- so the Requests list showed "Barong Embroidery" while the rest of the app
-- selects "Filipino Embroidery". Reparent the stored context to match.

update public.connections c
set skill_path = parent.path::text,
    skill_name = parent.name
from public.skill_nodes n
join public.skill_nodes parent on parent.id = n.parent_id
where n.depth > 2
  and c.skill_path = n.path::text;

update public.connections c
set skill_name = parent.name
from public.skill_nodes n
join public.skill_nodes parent on parent.id = n.parent_id
where n.depth > 2
  and c.skill_path is null
  and lower(c.skill_name) = lower(n.name);

-- Paths captured before the depth-2 rename still point at the old prefix.
-- Match by the stored skill name as well, then rewrite both fields.
update public.connections c
set skill_path = parent.path::text,
    skill_name = parent.name
from public.skill_nodes n
join public.skill_nodes parent on parent.id = n.parent_id
where n.depth > 2
  and lower(c.skill_name) = lower(n.name);
