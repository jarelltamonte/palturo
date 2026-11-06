-- Requests need to know which skill triggered the connection so the receiver
-- can filter by their declared skill categories. The old payload only had the
-- requester's full skill list, which is not precise enough for that filter.

alter table public.connections
  add column if not exists skill_name text,
  add column if not exists skill_path text;

drop function if exists public.browse_skill_users(text, public.skill_kind, integer);

create or replace function public.browse_skill_users(
  p_node text,
  p_kind public.skill_kind default 'teach'::public.skill_kind,
  p_limit integer default 50
)
returns table (
  user_id uuid,
  name text,
  role text,
  avatar_url text,
  note text,
  availability jsonb,
  languages text[],
  learning_styles text[],
  skill_name text,
  skill_path text
)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $$
  select distinct on (us.user_id)
    us.user_id,
    coalesce(p.display_name, ''),
    p.role::text,
    p.avatar_url,
    case when us.note_approved then us.note else null end,
    coalesce(p.availability, '{}'::jsonb),
    coalesce(p.languages, '{}'::text[]),
    coalesce(p.learning_styles, '{}'::text[]),
    n.name,
    n.path::text
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  where (p_node::extensions.ltree @> n.path)
    and us.kind = p_kind
    and n.status = 'approved'
    and p.has_completed_onboarding
    and (auth.uid() is null or us.user_id <> auth.uid())
    and not exists (
      select 1
      from public.blocks b
      where auth.uid() is not null
        and ((b.blocker_id = auth.uid() and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = auth.uid()))
    )
  order by us.user_id, n.usage_count desc, n.name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

revoke all on function public.browse_skill_users(text, public.skill_kind, integer)
  from public, anon;
grant execute on function public.browse_skill_users(text, public.skill_kind, integer)
  to authenticated, service_role;

drop function if exists public.get_incoming_requests(integer);

create or replace function public.get_incoming_requests(p_limit integer default 25)
returns table (
  connection_id uuid,
  requester_id uuid,
  requester_name text,
  avatar_url text,
  skills text[],
  requested_skill_name text,
  requested_skill_path text,
  in_declared_domain boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
with mine as (
  select * from public.connections
  where recipient_id = auth.uid() and status = 'pending'
),
sk as (
  select us.user_id,
    coalesce(array_agg(distinct n.name order by n.name), '{}') as skills
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  group by us.user_id
),
me as (
  select coalesce(skill_categories, '{}') as categories
  from public.profiles
  where id = auth.uid()
)
select
  m.id,
  m.requester_id,
  coalesce(p.display_name, ''),
  p.avatar_url,
  sk.skills,
  coalesce(m.skill_name, (sk.skills)[1]),
  m.skill_path,
  case
    when m.skill_path is null then null
    else exists (
      select 1
      from unnest(me.categories) as category
      where m.skill_path = category
         or m.skill_path like category || '.%'
         or m.skill_path like '%.' || category || '.%'
    )
  end,
  m.created_at
from mine m
join public.profiles p on p.id = m.requester_id
left join sk on sk.user_id = m.requester_id
left join me on true
order by m.created_at desc
limit greatest(1, least(coalesce(p_limit, 25), 100));
$$;

revoke all on function public.get_incoming_requests(integer) from public, anon;
grant execute on function public.get_incoming_requests(integer)
  to authenticated, service_role;

drop function if exists public.send_connection_request(uuid);

create or replace function public.send_connection_request(
  p_recipient uuid,
  p_skill_name text default null,
  p_skill_path text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  me uuid := auth.uid();
  conn uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_recipient then raise exception 'You cannot connect with yourself'; end if;
  if public.blocked_between(me, p_recipient) then
    raise exception 'Cannot connect with this user';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = p_recipient and has_completed_onboarding
  ) then
    raise exception 'Recipient profile is not ready';
  end if;

  select id into conn from public.connections
  where (requester_id = me and recipient_id = p_recipient)
     or (requester_id = p_recipient and recipient_id = me);

  if conn is not null then
    update public.connections
    set status = 'pending',
        requester_id = me,
        recipient_id = p_recipient,
        responded_at = null,
        skill_name = coalesce(nullif(btrim(p_skill_name), ''), skill_name),
        skill_path = coalesce(nullif(btrim(p_skill_path), ''), skill_path)
    where id = conn and status = 'declined';
    return conn;
  end if;

  insert into public.connections (
    requester_id,
    recipient_id,
    skill_name,
    skill_path
  )
  values (
    me,
    p_recipient,
    nullif(btrim(p_skill_name), ''),
    nullif(btrim(p_skill_path), '')
  )
  returning id into conn;

  perform public.notify(
    p_recipient,
    'connection_request',
    jsonb_build_object('connection_id', conn, 'requester_id', me)
  );
  return conn;
end;
$$;

revoke all on function public.send_connection_request(uuid, text, text)
  from public, anon;
grant execute on function public.send_connection_request(uuid, text, text)
  to authenticated, service_role;
