-- Per-chat QOL state (mute + manual unread), private to each user.
-- Clients never write the table directly; the RPCs below validate membership.

create table if not exists public.connection_preferences (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  connection_id uuid not null references public.connections(id) on delete cascade,
  muted_until timestamptz,
  marked_unread boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, connection_id)
);

alter table public.connection_preferences enable row level security;

drop policy if exists cp_read on public.connection_preferences;
create policy cp_read on public.connection_preferences
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.connection_preferences from public;
revoke all on public.connection_preferences from anon, authenticated;
grant select on public.connection_preferences to authenticated;
grant all on public.connection_preferences to service_role;

create or replace function public.set_connection_mute(
  p_connection_id uuid,
  p_muted_until timestamptz
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (
    select 1
    from public.connections c
    where c.id = p_connection_id
      and (c.requester_id = auth.uid() or c.recipient_id = auth.uid())
  ) then
    raise exception 'Not allowed';
  end if;

  insert into public.connection_preferences (
    user_id, connection_id, muted_until, updated_at
  )
  values (auth.uid(), p_connection_id, p_muted_until, now())
  on conflict (user_id, connection_id) do update
    set muted_until = excluded.muted_until,
        updated_at = now();
end
$$;

create or replace function public.set_connection_unread(
  p_connection_id uuid,
  p_unread boolean default true
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (
    select 1
    from public.connections c
    where c.id = p_connection_id
      and (c.requester_id = auth.uid() or c.recipient_id = auth.uid())
  ) then
    raise exception 'Not allowed';
  end if;

  insert into public.connection_preferences (
    user_id, connection_id, marked_unread, updated_at
  )
  values (auth.uid(), p_connection_id, coalesce(p_unread, true), now())
  on conflict (user_id, connection_id) do update
    set marked_unread = excluded.marked_unread,
        updated_at = now();
end
$$;

create or replace function public.get_connection_preferences()
returns table (
  connection_id uuid,
  muted_until timestamptz,
  marked_unread boolean
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select cp.connection_id, cp.muted_until, cp.marked_unread
  from public.connection_preferences cp
  where cp.user_id = auth.uid();
$$;

revoke all on function public.set_connection_mute(uuid, timestamptz) from public;
revoke all on function public.set_connection_mute(uuid, timestamptz) from anon;
grant execute on function public.set_connection_mute(uuid, timestamptz) to authenticated;
grant execute on function public.set_connection_mute(uuid, timestamptz) to service_role;

revoke all on function public.set_connection_unread(uuid, boolean) from public;
revoke all on function public.set_connection_unread(uuid, boolean) from anon;
grant execute on function public.set_connection_unread(uuid, boolean) to authenticated;
grant execute on function public.set_connection_unread(uuid, boolean) to service_role;

revoke all on function public.get_connection_preferences() from public;
revoke all on function public.get_connection_preferences() from anon;
grant execute on function public.get_connection_preferences() to authenticated;
grant execute on function public.get_connection_preferences() to service_role;

-- Chat list rows now carry mute + manual-unread state.
drop function if exists public.get_conversations();

create or replace function public.get_conversations()
returns table (
  connection_id uuid,
  status text,
  other_user_id uuid,
  other_name text,
  other_role text,
  last_message text,
  last_at timestamptz,
  unread integer,
  other_avatar text,
  other_skill text,
  muted_until timestamptz,
  marked_unread boolean
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
#variable_conflict use_column
declare me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  return query
  with mine as (
    select cx.* from public.connections cx
    where cx.requester_id = me or cx.recipient_id = me
  ),
  others as (
    select m.id as conn_id, m.status as conn_status,
      case when m.requester_id = me then m.recipient_id else m.requester_id end as other_id,
      case when m.requester_id = me then m.requester_read_at else m.recipient_read_at end as my_read
    from mine m
  )
  select o.conn_id, o.conn_status::text, o.other_id,
    coalesce(p.display_name, ''),
    p.role::text,
    lm.body,
    lm.created_at,
    (select count(*)::int from public.messages mm
      where mm.connection_id = o.conn_id
        and mm.sender_id = o.other_id
        and mm.created_at > coalesce(o.my_read, '1970-01-01'::timestamptz))::int,
    p.avatar_url,
    coalesce(
      case
        when p.role::text = 'mentor' then (p.teaching_skills)[1]
        when p.role::text = 'learner' then (p.learning_skills)[1]
        else coalesce((p.teaching_skills)[1], (p.learning_skills)[1])
      end,
      ''
    ) as other_skill,
    cp.muted_until,
    coalesce(cp.marked_unread, false)
  from others o
  join public.profiles p on p.id = o.other_id
  left join public.connection_preferences cp
    on cp.connection_id = o.conn_id and cp.user_id = me
  left join lateral (
    select lg.body as body, lg.created_at as created_at
    from public.messages lg
    where lg.connection_id = o.conn_id
    order by lg.created_at desc limit 1
  ) lm on true
  order by lm.created_at desc nulls last;
end
$$;

revoke all on function public.get_conversations() from public;
revoke all on function public.get_conversations() from anon;
grant execute on function public.get_conversations() to authenticated;
grant execute on function public.get_conversations() to service_role;
