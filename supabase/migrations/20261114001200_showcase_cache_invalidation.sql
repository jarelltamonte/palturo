-- A showcase change must make the owner discoverable without waiting for the
-- deck cache TTL, and removing media must take them out just as quickly.
-- Clear cached decks once, then on showcase/media changes.

delete from public.match_cache;

create or replace function public.invalidate_all_match_cache()
returns trigger
language plpgsql
security definer
set search_path = 'public'
as $$
begin
  delete from public.match_cache;
  return null;
end;
$$;

drop trigger if exists invalidate_showcase_match_cache on public.skill_showcases;
create trigger invalidate_showcase_match_cache
  after insert or update or delete on public.skill_showcases
  for each statement execute function public.invalidate_all_match_cache();

drop trigger if exists invalidate_profile_media_match_cache on public.profiles;
create trigger invalidate_profile_media_match_cache
  after update of teaching_skill_images on public.profiles
  for each statement execute function public.invalidate_all_match_cache();
