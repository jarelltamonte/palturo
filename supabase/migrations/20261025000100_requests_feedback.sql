-- Outgoing requests, request withdrawal, and app-level feedback.
--
-- These close audit gaps that cannot be solved safely in the client:
--   * Requests only exposed incoming pending connections (FR-10).
--   * A swipe could send a request but there was no way to withdraw it.
--   * Settings feedback/problem reports were written only to SharedPreferences.

create or replace function public.get_outgoing_requests(p_limit integer default 25)
returns table (
  connection_id uuid,
  recipient_id uuid,
  recipient_name text,
  avatar_url text,
  skills text[],
  status text,
  created_at timestamp with time zone
)
language sql
stable
security definer
set search_path = public
as $$
with mine as (
  select * from public.connections
  where requester_id = auth.uid()
    and status in ('pending', 'declined')
),
sk as (
  select us.user_id,
    coalesce(array_agg(distinct n.name order by n.name), '{}') as skills
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  group by us.user_id
)
select
  m.id,
  m.recipient_id,
  coalesce(p.display_name, ''),
  p.avatar_url,
  sk.skills,
  m.status::text,
  m.created_at
from mine m
join public.profiles p on p.id = m.recipient_id
left join sk on sk.user_id = m.recipient_id
order by m.created_at desc
limit greatest(1, least(p_limit, 100));
$$;

revoke all on function public.get_outgoing_requests(integer) from public, anon;
grant execute on function public.get_outgoing_requests(integer) to authenticated;

create or replace function public.cancel_connection_request(p_connection uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  c public.connections%rowtype;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;

  if p_connection is null then
    raise exception 'Connection is required';
  end if;

  select * into c from public.connections where id = p_connection;
  if not found then
    -- Idempotent: a retry after a successful withdrawal is a no-op.
    return;
  end if;

  if c.requester_id <> me then
    raise exception 'Only the sender can withdraw this request';
  end if;

  if c.status <> 'pending' then
    raise exception 'Only pending requests can be withdrawn';
  end if;

  delete from public.connections where id = p_connection;

  -- Remove the recipient's stale connection_request notification as well.
  delete from public.notifications n
  where n.user_id = c.recipient_id
    and n.kind = 'connection_request'
    and (n.payload->>'connection_id')::uuid = p_connection;
end;
$$;

revoke all on function public.cancel_connection_request(uuid) from public, anon;
grant execute on function public.cancel_connection_request(uuid) to authenticated;

create table if not exists public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('survey', 'problem')),
  payload jsonb not null,
  created_at timestamp with time zone not null default now()
);

create index if not exists idx_app_feedback_created_at
  on public.app_feedback (created_at desc);
create index if not exists idx_app_feedback_user
  on public.app_feedback (user_id, created_at desc);

alter table public.app_feedback enable row level security;

drop policy if exists "app_feedback_insert_own" on public.app_feedback;
create policy "app_feedback_insert_own"
  on public.app_feedback
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "app_feedback_select_own"
  on public.app_feedback
  for select
  to authenticated
  using (user_id = auth.uid());

revoke all on table public.app_feedback from public, anon, authenticated;
grant select, insert on table public.app_feedback to authenticated;
grant all on table public.app_feedback to service_role;
