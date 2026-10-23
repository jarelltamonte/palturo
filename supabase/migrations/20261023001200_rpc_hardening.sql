-- B11 follow-up: client RPCs must not be executable by anon/PUBLIC, and
-- get_conversation must not treat a null auth.uid() as a participant.
-- Also close the default ACLs that re-created the old grants on new objects.

create or replace function public.get_conversation(
  p_connection uuid,
  p_limit integer default 200
)
returns table(id uuid, sender_id uuid, body text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $function$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  c public.connections%rowtype;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;
  select * into c from public.connections where connections.id = p_connection;
  if not found then raise exception 'Connection not found'; end if;
  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;
  if c.requester_id = me then
    update public.connections set requester_read_at = now()
    where connections.id = p_connection;
  else
    update public.connections set recipient_read_at = now()
    where connections.id = p_connection;
  end if;
  return query
    select msg.id, msg.sender_id, msg.body, msg.created_at
    from public.messages msg
    where msg.connection_id = p_connection
    order by msg.created_at desc
    limit p_limit;
end
$function$;

create or replace function public.get_conversations()
returns table(
  connection_id uuid, status text, other_user_id uuid, other_name text,
  other_role text, last_message text, last_at timestamptz, unread integer,
  other_avatar text, other_skill text
)
language plpgsql
stable
security definer
set search_path = public
as $function$
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
    ) as other_skill
  from others o
  join public.profiles p on p.id = o.other_id
  left join lateral (
    select lg.body as body, lg.created_at as created_at
    from public.messages lg
    where lg.connection_id = o.conn_id
    order by lg.created_at desc limit 1
  ) lm on true
  order by lm.created_at desc nulls last;
end
$function$;

-- Client RPCs: authenticated only.
revoke all on function public.get_conversation(uuid, integer) from public, anon;
revoke all on function public.get_conversations() from public, anon;
revoke all on function public.send_message(uuid, text) from public, anon;
revoke all on function public.mark_messages_read(uuid) from public, anon;
revoke all on function public.count_unread_notifications() from public, anon;
revoke all on function public.mark_notifications_read() from public, anon;
revoke all on function public.list_notifications(boolean, integer) from public, anon;
revoke all on function public.get_incoming_requests(integer) from public, anon;
revoke all on function public.send_connection_request(uuid) from public, anon;
revoke all on function public.respond_connection_request(uuid, boolean) from public, anon;
revoke all on function public.unmatch_connection(uuid) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
revoke all on function public.get_block_list() from public, anon;
revoke all on function public.report_user(uuid, text, text) from public, anon;
revoke all on function public.browse_random_users(integer) from public, anon;
revoke all on function public.taxonomy_visible(text) from public, anon;
revoke all on function public.set_availability_slots(jsonb) from public, anon;
revoke all on function public.submit_feedback(uuid, smallint, smallint) from public, anon;

grant execute on function public.get_conversation(uuid, integer) to authenticated;
grant execute on function public.get_conversations() to authenticated;
grant execute on function public.send_message(uuid, text) to authenticated;
grant execute on function public.mark_messages_read(uuid) to authenticated;
grant execute on function public.count_unread_notifications() to authenticated;
grant execute on function public.mark_notifications_read() to authenticated;
grant execute on function public.list_notifications(boolean, integer) to authenticated;
grant execute on function public.get_incoming_requests(integer) to authenticated;
grant execute on function public.send_connection_request(uuid) to authenticated;
grant execute on function public.respond_connection_request(uuid, boolean) to authenticated;
grant execute on function public.unmatch_connection(uuid) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.get_block_list() to authenticated;
grant execute on function public.report_user(uuid, text, text) to authenticated;
grant execute on function public.browse_random_users(integer) to authenticated;
grant execute on function public.taxonomy_visible(text) to authenticated;
grant execute on function public.set_availability_slots(jsonb) to authenticated;
grant execute on function public.submit_feedback(uuid, smallint, smallint) to authenticated;

-- Public profile remains the one anon-readable RPC (share links).
revoke all on function public.get_public_profile(uuid) from public;
grant execute on function public.get_public_profile(uuid) to anon, authenticated;

-- Everything not explicitly client-callable is owner/service-only. This
-- closes the old default-ACL EXECUTE grants on internal helpers.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure::text as sig, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.proname not in (
        'email_exists', 'get_public_profile', 'is_admin', 'save_user_skills',
        'get_conversation', 'get_conversations', 'send_message',
        'mark_messages_read', 'count_unread_notifications',
        'mark_notifications_read', 'list_notifications',
        'get_incoming_requests', 'send_connection_request',
        'respond_connection_request', 'unmatch_connection', 'block_user',
        'unblock_user', 'get_block_list', 'report_user', 'browse_random_users',
        'browse_skill_users', 'taxonomy_visible', 'submit_feedback',
        'set_availability_slots'
      )
  loop
    execute format(
      'revoke all on function %s from public, anon, authenticated', r.sig
    );
  end loop;
end $$;

-- No stray DDL privileges on internal tables.
revoke maintain on table
  public.user_skills, public.skill_nodes, public.user_skill_notes,
  public.note_moderation_queue
from authenticated;
revoke select on public.note_moderation_queue from authenticated;

-- Future objects must not inherit the old anon/authenticated ALL grants.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;

do $$
begin
  begin
    execute 'alter default privileges for role supabase_admin in schema public revoke all on tables from anon, authenticated';
    execute 'alter default privileges for role supabase_admin in schema public revoke all on sequences from anon, authenticated';
    execute 'alter default privileges for role supabase_admin in schema public revoke all on functions from anon, authenticated';
  exception when others then
    -- Role may not be manageable from the migration owner; postgres defaults
    -- are the ones used by these migrations.
    null;
  end;
end $$;
