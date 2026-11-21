-- Owner-only note review status.
--
-- The queue itself is not client-readable (it carries moderation internals).
-- This RPC exposes only the status needed to tell the author whether a note is
-- still being reviewed or was rejected, so the profile can highlight it.

create or replace function public.get_my_note_reviews()
returns table (
  kind public.skill_kind,
  name text,
  status text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select distinct on (q.kind, coalesce(n.name, q.name))
    q.kind,
    coalesce(n.name, q.name) as name,
    q.status,
    q.updated_at
  from public.note_moderation_queue q
  left join public.skill_nodes n on n.id = q.skill_id
  where q.user_id = auth.uid()
    and q.status in ('pending', 'rejected')
    and q.note is not null
    and btrim(q.note) <> ''
  order by q.kind, coalesce(n.name, q.name), q.updated_at desc;
$$;

revoke all on function public.get_my_note_reviews()
  from public, anon, authenticated;
grant execute on function public.get_my_note_reviews()
  to authenticated;
