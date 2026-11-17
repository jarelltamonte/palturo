-- The match-cache invalidation triggers ran an unfiltered
-- `delete from public.match_cache`, which the database's safe-update guard
-- rejects. Every showcase write and every profile update that touched
-- teaching_skill_images therefore failed with "DELETE requires a WHERE
-- clause", which surfaced as "Couldn't save your profile".
--
-- Keep the full invalidation but make the statement explicit.

create or replace function public.invalidate_all_match_cache()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  delete from public.match_cache where true;
  return null;
end;
$$;
