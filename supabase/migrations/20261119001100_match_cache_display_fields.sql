-- Cached decks now carry the display name and role, so rendering a cached
-- deck no longer rebuilds every candidate's passages through
-- profile_match_view. Clear the old rows once so they are repopulated.
alter table public.match_cache
  add column if not exists display_name text not null default '',
  add column if not exists role text not null default 'both';

delete from public.match_cache where true;
