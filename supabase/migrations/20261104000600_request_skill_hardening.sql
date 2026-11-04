-- Harden request skill context: validate paths at write time, backfill legacy
-- rows from the requester's first placement, and guard the ltree cast in reads.

-- Backfill the context for rows created before skill context existed.
with first_skill as (
  select
    us.user_id,
    n.name as skill_name,
    n.path::text as skill_path,
    row_number() over (
      partition by us.user_id
      order by n.usage_count desc, n.name
    ) as rn
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
)
update public.connections c
set skill_name = s.skill_name,
    skill_path = s.skill_path
from first_skill s
where s.user_id = c.requester_id
  and s.rn = 1
  and (c.skill_name is null or c.skill_path is null);

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
  clean_path text := nullif(btrim(p_skill_path), '');
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
  if clean_path is not null and not exists (
    select 1 from public.skill_nodes where path::text = clean_path
  ) then
    raise exception 'Invalid skill context';
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
        skill_path = coalesce(clean_path, skill_path)
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
    clean_path
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

drop function if exists public.get_incoming_requests(integer);

create or replace function public.get_incoming_requests(p_limit integer default 25)
returns table (
  connection_id uuid,
  requester_id uuid,
  requester_name text,
  requester_role text,
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
set search_path to 'public', 'extensions'
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
)
select
  m.id,
  m.requester_id,
  coalesce(p.display_name, ''),
  p.role::text,
  p.avatar_url,
  sk.skills,
  coalesce(m.skill_name, (sk.skills)[1]),
  m.skill_path,
  case
    when m.skill_path is null
      or m.skill_path !~ '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*$'
      then null
    else exists (
      select 1
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.user_id = auth.uid()
        and n.path @> m.skill_path::extensions.ltree
    )
  end,
  m.created_at
from mine m
join public.profiles p on p.id = m.requester_id
left join sk on sk.user_id = m.requester_id
order by m.created_at desc
limit greatest(1, least(coalesce(p_limit, 25), 100));
$$;

revoke all on function public.get_incoming_requests(integer) from public, anon;
grant execute on function public.get_incoming_requests(integer)
  to authenticated, service_role;
