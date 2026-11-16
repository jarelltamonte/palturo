-- A connection request now records the discovery surface that produced it, so
-- the recipient can see "Found you as a match" / "Discovered you in Explore"
-- instead of guessing where the request came from. Legacy rows stay 'unknown'
-- and show no note.

alter table public.connections
  add column if not exists request_source text not null default 'unknown';

alter table public.connections
  drop constraint if exists connections_request_source_check;

alter table public.connections
  add constraint connections_request_source_check
  check (request_source in ('match', 'explore', 'browse', 'unknown'));

-- The old 3-argument signature is replaced by the same function with an
-- optional p_source. Defaults keep old clients working.
drop function if exists public.send_connection_request(uuid, text, text);

create or replace function public.send_connection_request(
  p_recipient uuid,
  p_skill_name text default null,
  p_skill_path text default null,
  p_source text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  me uuid := auth.uid();
  conn uuid;
  clean_path text := nullif(btrim(p_skill_path), '');
  clean_source text := case
    when p_source in ('match', 'explore', 'browse') then p_source
    else 'unknown'
  end;
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

  perform pg_advisory_xact_lock(
    hashtextextended(
      least(me, p_recipient)::text || ':' || greatest(me, p_recipient)::text,
      0
    )
  );

  select id into conn from public.connections
  where (requester_id = me and recipient_id = p_recipient)
     or (requester_id = p_recipient and recipient_id = me)
  for update;

  if conn is not null then
    if public.blocked_between(me, p_recipient) then
      raise exception 'Cannot connect with this user';
    end if;
    update public.connections
    set status = 'pending',
        requester_id = me,
        recipient_id = p_recipient,
        responded_at = null,
        skill_name = coalesce(nullif(btrim(p_skill_name), ''), skill_name),
        skill_path = coalesce(clean_path, skill_path),
        request_source = clean_source
    where id = conn and status = 'declined';
    if not found then
      -- Keep the RPC idempotent for a retry after a lost response.
      if exists (
        select 1 from public.connections
        where id = conn and status in ('pending', 'accepted')
      ) then
        return conn;
      end if;
      raise exception 'Request state changed';
    end if;
    return conn;
  end if;

  insert into public.connections (
    requester_id,
    recipient_id,
    skill_name,
    skill_path,
    request_source
  )
  values (
    me,
    p_recipient,
    nullif(btrim(p_skill_name), ''),
    clean_path,
    clean_source
  )
  returning id into conn;

  -- Close the insert race: if a block committed while this row was being
  -- created, remove it and fail.
  if public.blocked_between(me, p_recipient) then
    delete from public.connections where id = conn;
    raise exception 'Cannot connect with this user';
  end if;

  perform public.notify(
    p_recipient,
    'connection_request',
    jsonb_build_object('connection_id', conn, 'requester_id', me)
  );
  return conn;
end;
$function$;

revoke all on function public.send_connection_request(uuid, text, text, text)
  from public, anon;
grant execute on function public.send_connection_request(uuid, text, text, text)
  to authenticated;

-- Adding a column to a RETURNS TABLE function requires a drop/recreate.
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
  request_source text,
  created_at timestamp with time zone
)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $function$
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
  m.request_source,
  m.created_at
from mine m
join public.profiles p on p.id = m.requester_id
left join sk on sk.user_id = m.requester_id
where not public.blocked_between(auth.uid(), m.requester_id)
order by m.created_at desc
limit greatest(1, least(coalesce(p_limit, 25), 100));
$function$;

revoke all on function public.get_incoming_requests(integer) from public, anon;
grant execute on function public.get_incoming_requests(integer) to authenticated;
