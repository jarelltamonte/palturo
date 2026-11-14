-- Explore is the escape hatch when For You runs out. It excluded every profile
-- already present in match_cache, which is exactly the curated deck, so on a
-- small pool it returned nobody. Randomize all eligible profiles instead; the
-- client already dedupes the cards it has just shown.

create or replace function public.browse_random_users(p_limit integer default 20)
returns table (
  user_id uuid,
  name text,
  role text,
  avatar_url text,
  bio text
)
language sql
security definer
set search_path to 'public'
as $$
  select p.id, coalesce(p.display_name, ''), p.role::text, p.avatar_url, p.bio
  from public.profiles p
  where p.has_completed_onboarding
    and p.id <> auth.uid()
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
    -- Explore is for new people, not the Pals and pending requests already in
    -- the Chats and Requests lists.
    and not exists (
      select 1 from public.connections c
      where (c.requester_id = auth.uid() and c.recipient_id = p.id)
         or (c.requester_id = p.id and c.recipient_id = auth.uid())
    )
  order by random()
  limit greatest(1, least(coalesce(p_limit, 20), 200));
$$;
