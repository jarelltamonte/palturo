-- PalTuro public schema baseline
-- Source: project yjcrfgvenilptrnudvcb, generated 2026-10-24 via
-- supabase db dump --linked --schema public




-- Prerequisites: run on a Supabase Postgres instance with the base roles
-- (anon, authenticated, service_role) and the auth schema. Extensions used by
-- the app live in the extensions schema.
create schema if not exists extensions;
create extension if not exists ltree with schema extensions;
create extension if not exists vector with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists supabase_vault;
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."conn_status" AS ENUM (
    'pending',
    'accepted',
    'declined'
);


ALTER TYPE "public"."conn_status" OWNER TO "postgres";


CREATE TYPE "public"."embed_field_group" AS ENUM (
    'skills',
    'context',
    'bio'
);


ALTER TYPE "public"."embed_field_group" OWNER TO "postgres";


CREATE TYPE "public"."embed_role" AS ENUM (
    'learner',
    'mentor'
);


ALTER TYPE "public"."embed_role" OWNER TO "postgres";


CREATE TYPE "public"."media_kind" AS ENUM (
    'image',
    'video'
);


ALTER TYPE "public"."media_kind" OWNER TO "postgres";


CREATE TYPE "public"."skill_kind" AS ENUM (
    'teach',
    'learn',
    'secondary'
);


ALTER TYPE "public"."skill_kind" OWNER TO "postgres";


CREATE TYPE "public"."skill_origin" AS ENUM (
    'official',
    'user_submitted'
);


ALTER TYPE "public"."skill_origin" OWNER TO "postgres";


CREATE TYPE "public"."skill_status" AS ENUM (
    'approved',
    'pending',
    'rejected'
);


ALTER TYPE "public"."skill_status" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'learner',
    'mentor',
    'both'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."block_user"("p_target" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_target then raise exception 'You cannot block yourself'; end if;
  insert into public.blocks (blocker_id, blocked_id) values (me, p_target) on conflict do nothing;
  update public.connections set status = 'declined', responded_at = now()
    where status = 'pending'
      and ((requester_id = me and recipient_id = p_target) or (requester_id = p_target and recipient_id = me));
end $$;


ALTER FUNCTION "public"."block_user"("p_target" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."blocked_between"("a" "uuid", "b" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (select 1 from public.blocks where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;


ALTER FUNCTION "public"."blocked_between"("a" "uuid", "b" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."browse_random_users"("p_limit" integer DEFAULT 20) RETURNS TABLE("user_id" "uuid", "name" "text", "role" "text", "avatar_url" "text", "bio" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select p.id, coalesce(p.display_name, ''), p.role::text, p.avatar_url, p.bio
  from public.profiles p
  where p.has_completed_onboarding and p.id <> auth.uid()
    and not exists (select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    and not exists (select 1 from public.match_cache mc
      where mc.user_id = auth.uid() and mc.candidate_id = p.id)
  order by random()
  limit p_limit
$$;


ALTER FUNCTION "public"."browse_random_users"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."browse_skill_users"("p_node" "text", "p_kind" "public"."skill_kind" DEFAULT 'teach'::"public"."skill_kind", "p_limit" integer DEFAULT 50) RETURNS TABLE("user_id" "uuid", "name" "text", "role" "text", "avatar_url" "text", "note" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions'
    AS $$
  select distinct on (us.user_id)
    us.user_id, coalesce(p.display_name,''), p.role::text, p.avatar_url,
    case when us.note_approved then us.note else null end
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  where (p_node::extensions.ltree @> n.path)
    and us.kind = p_kind
    and n.status = 'approved'
    and p.has_completed_onboarding
  order by us.user_id, n.usage_count desc
  limit p_limit
$$;


ALTER FUNCTION "public"."browse_skill_users"("p_node" "text", "p_kind" "public"."skill_kind", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."build_passages_bulk"("p_users" "uuid"[]) RETURNS TABLE("user_id" "uuid", "role" "public"."embed_role", "field_group" "public"."embed_field_group", "source_text" "text", "source_hash" "text")
    LANGUAGE "sql" STABLE
    AS $$
select u.uid, x.role, x.field_group, x.source_text, x.source_hash
from unnest(p_users) as u(uid)
cross join lateral build_profile_passages(u.uid) x
$$;


ALTER FUNCTION "public"."build_passages_bulk"("p_users" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."build_profile_passages"("p_user" "uuid") RETURNS TABLE("role" "public"."embed_role", "field_group" "public"."embed_field_group", "source_text" "text", "source_hash" "text")
    LANGUAGE "sql" STABLE
    AS $$
with declared as (
  select us.kind,
    case when us.note_approved then us.note else null end as note,
    leaf.path, leaf.name
  from public.user_skills us
  join public.skill_nodes leaf on leaf.id = us.skill_id
  where us.user_id = p_user and leaf.is_leaf
),
chains as (
  select d.kind, d.note, d.name as leaf_name,
    (select string_agg(a.name, ' > ' order by a.depth)
     from public.skill_nodes a where a.path @> d.path) as chain
  from declared d
),
avail as (
  select p.id as pid,
    coalesce(
      case jsonb_typeof(p.availability)
        when 'object' then (
          select string_agg(k, ', ')
          from jsonb_object_keys(p.availability) as k
        )
        when 'array' then (
          select string_agg(v, ', ')
          from jsonb_array_elements_text(p.availability) as v
        )
        else ''
      end,
      ''
    ) as days,
    p.timezone
  from public.profiles p where p.id = p_user
)
select r.role, r.fg, r.txt, md5(r.txt)
from (
  select 'mentor'::public.embed_role as role, 'skills'::public.embed_field_group as fg,
    'Offers to teach: ' || coalesce((
      select string_agg(c.chain || (case when c.note is not null and c.note <> '' then ' - note: ' || c.note else '' end), '; ')
      from chains c where c.kind = 'teach'), '') || '.' as txt
  union all
  select 'learner'::public.embed_role, 'skills'::public.embed_field_group,
    'Wants to learn: ' || coalesce((
      select string_agg(c.chain || (case when c.note is not null and c.note <> '' then ' - note: ' || c.note else '' end), '; ')
      from chains c where c.kind = 'learn'), '') || '.' as txt
  union all
  select 'mentor'::public.embed_role, 'context'::public.embed_field_group,
    'Teaching preferences. Languages: ' || coalesce(array_to_string(p.languages, ', '),'') ||
    case when coalesce(array_length(p.learning_styles,1),0) > 0
      then '; Own learning styles: ' || array_to_string(p.learning_styles, ', ') else '' end ||
    case when a.days <> '' then '; Available: ' || a.days || ' (' || coalesce(a.timezone,'Asia/Manila') || ')' else '' end || '.'
  from public.profiles p join avail a on a.pid = p.id
  where p.id = p_user
  union all
  select 'learner'::public.embed_role, 'context'::public.embed_field_group,
    'Learning preferences. Languages: ' || coalesce(array_to_string(p.languages, ', '),'') ||
    case when coalesce(array_length(p.learning_styles,1),0) > 0
      then '; Learning styles: ' || array_to_string(p.learning_styles, ', ') else '' end ||
    case when a.days <> '' then '; Available: ' || a.days || ' (' || coalesce(a.timezone,'Asia/Manila') || ')' else '' end || '.'
  from public.profiles p join avail a on a.pid = p.id
  where p.id = p_user
) r
where r.txt is not null and btrim(r.txt) <> '';
$$;


ALTER FUNCTION "public"."build_profile_passages"("p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bump_config_revision"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.key = '__revision' then return null; end if;
  insert into public.pipeline_config (key, value, description)
    values ('__revision', to_jsonb(1), 'internal revision counter (do not edit)')
    on conflict (key) do update
      set value = to_jsonb(((public.pipeline_config.value #>> '{}')::int) + 1),
          updated_at = now();
  return null;
end $$;


ALTER FUNCTION "public"."bump_config_revision"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cache_is_fresh"("p_user" "uuid", "p_role" "public"."embed_role", "p_revision" integer) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.match_cache mc
    join public.profiles own on own.id = mc.user_id
    where mc.user_id = p_user and mc.as_role = p_role
      and mc.config_version = p_revision
      and mc.refreshed_at > own.updated_at
      and not exists (
        select 1 from public.user_skills ownus
        where ownus.user_id = p_user and ownus.updated_at > mc.refreshed_at
      )
      and not exists (
        select 1 from public.profiles cand
        join public.match_cache m2 on m2.user_id = mc.user_id and m2.as_role = mc.as_role
        where cand.id = m2.candidate_id and cand.updated_at > m2.refreshed_at
      )
      and not exists (
        select 1 from public.user_skills cs
        join public.match_cache m3 on m3.user_id = mc.user_id and m3.as_role = mc.as_role
        where cs.user_id = m3.candidate_id and cs.updated_at > m3.refreshed_at
      )
  )
$$;


ALTER FUNCTION "public"."cache_is_fresh"("p_user" "uuid", "p_role" "public"."embed_role", "p_revision" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_feedback_gate"("p_connection" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  n int;
  a uuid;
  b uuid;
  me uuid := auth.uid();
begin
  if me is null then
    return;
  end if;
  if not exists (
    select 1 from public.connections c
    where c.id = p_connection
      and (c.requester_id = me or c.recipient_id = me)
  ) then
    return;
  end if;
  if (select count(*) from public.notifications n2
      where n2.kind = 'feedback_ready'
        and (n2.payload->>'connection_id')::uuid = p_connection) >= 1 then
    return;
  end if;
  select count(*) into n from public.messages m where m.connection_id = p_connection;
  if n >= 15 then
    select requester_id, recipient_id into a, b
    from public.connections where id = p_connection;
    perform public.notify(a, 'feedback_ready', jsonb_build_object('connection_id', p_connection));
    perform public.notify(b, 'feedback_ready', jsonb_build_object('connection_id', p_connection));
  end if;
end;
$$;


ALTER FUNCTION "public"."check_feedback_gate"("p_connection" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."note_moderation_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "kind" "public"."skill_kind" NOT NULL,
    "name" "text" NOT NULL,
    "skill_id" "uuid",
    "note" "text" NOT NULL,
    "note_hash" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "last_error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "note_moderation_queue_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'approved'::"text", 'rejected'::"text", 'unresolved'::"text", 'error'::"text", 'stale'::"text"])))
);


ALTER TABLE "public"."note_moderation_queue" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_note_jobs"("p_limit" integer DEFAULT 10) RETURNS SETOF "public"."note_moderation_queue"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.note_moderation_queue q
  set status = 'processing',
      attempts = q.attempts + 1,
      updated_at = now()
  where q.id in (
    select id from public.note_moderation_queue
    where (
        status = 'pending'
        or (status = 'processing' and updated_at < now() - interval '5 minutes')
      )
      and attempts < 5
    order by created_at
    limit p_limit
    for update skip locked
  )
  returning q.*;
$$;


ALTER FUNCTION "public"."claim_note_jobs"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."consume_rate_limit"("p_subject" "uuid", "p_action" "text", "p_limit" integer, "p_window_seconds" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_window timestamptz;
  v_count integer;
begin
  if p_subject is null or btrim(coalesce(p_action, '')) = ''
     or p_limit <= 0 or p_window_seconds <= 0 then
    return false;
  end if;

  v_window := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );

  insert into public.rate_limits (subject, action, window_start, count)
  values (p_subject, p_action, v_window, 1)
  on conflict (subject, action, window_start)
  do update set count = public.rate_limits.count + 1
  returning count into v_count;

  return v_count <= p_limit;
end;
$$;


ALTER FUNCTION "public"."consume_rate_limit"("p_subject" "uuid", "p_action" "text", "p_limit" integer, "p_window_seconds" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."count_unread_notifications"() RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select count(*)::int from public.notifications where user_id = auth.uid() and read_at is null
$$;


ALTER FUNCTION "public"."count_unread_notifications"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."email_exists"("p_email" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.profiles
    where email = lower(btrim(p_email))
  );
$$;


ALTER FUNCTION "public"."email_exists"("p_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_leaf_only"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare ok boolean;
begin
  select is_leaf into ok from public.skill_nodes where id = new.skill_id;
  if ok is not true then
    raise exception 'Only leaf skill nodes can be declared';
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."enforce_leaf_only"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_skill_caps"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare n int;
begin
  if new.kind = 'secondary' then return new; end if;
  select count(*) into n from public.user_skills
    where user_id = new.user_id and kind = new.kind and id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);
  if n >= 3 then
    raise exception 'Skill cap reached: maximum 3 skills of kind "%"', new.kind;
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."enforce_skill_caps"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."feedback_gate_open"("p_connection" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select (select count(*) from public.messages m where m.connection_id = p_connection) >= 15
$$;


ALTER FUNCTION "public"."feedback_gate_open"("p_connection" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_block_list"() RETURNS TABLE("blocked_id" "uuid", "name" "text", "avatar_url" "text", "blocked_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select b.blocked_id, coalesce(p.display_name,''), p.avatar_url, b.created_at
  from public.blocks b join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid() order by b.created_at desc
$$;


ALTER FUNCTION "public"."get_block_list"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_conversation"("p_connection" "uuid", "p_limit" integer DEFAULT 200) RETURNS TABLE("id" "uuid", "sender_id" "uuid", "body" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_conversation"("p_connection" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_conversations"() RETURNS TABLE("connection_id" "uuid", "status" "text", "other_user_id" "uuid", "other_name" "text", "other_role" "text", "last_message" "text", "last_at" timestamp with time zone, "unread" integer, "other_avatar" "text", "other_skill" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_conversations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_incoming_requests"("p_limit" integer DEFAULT 25) RETURNS TABLE("connection_id" "uuid", "requester_id" "uuid", "requester_name" "text", "avatar_url" "text", "skills" "text"[], "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
with mine as (
  select * from public.connections where recipient_id = auth.uid() and status = 'pending'
),
sk as (
  select us.user_id,
    coalesce(array_agg(distinct n.name order by n.name), '{}') as skills
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  group by us.user_id
)
select m.id, m.requester_id, coalesce(p.display_name, ''), p.avatar_url, sk.skills, m.created_at
from mine m
join public.profiles p on p.id = m.requester_id
left join sk on sk.user_id = m.requester_id
order by m.created_at desc limit p_limit
$$;


ALTER FUNCTION "public"."get_incoming_requests"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_public_profile"("p_user" "uuid", OUT "p_name" "text", OUT "p_role" "text", OUT "p_bio" "text", OUT "p_avatar" "text", OUT "p_languages" "text", OUT "p_styles" "text", OUT "p_availability" "jsonb", OUT "p_teaching" "jsonb", OUT "p_learning" "jsonb", OUT "p_showcases" "jsonb") RETURNS "record"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare u public.profiles%rowtype;
begin
  select * into u from public.profiles where id = p_user;
  if not found then raise exception 'Profile not found'; end if;
  p_name := coalesce(u.display_name,''); p_role := u.role::text; p_bio := u.bio; p_avatar := u.avatar_url;
  p_languages := array_to_string(u.languages, ', ');
  p_styles := array_to_string(u.learning_styles, ', ');
  p_availability := u.availability;
  select coalesce(jsonb_agg(jsonb_build_object(
      'skill', n.name, 'path', n.path::text,
      'note', case when us.note_approved then us.note else null end
    ) order by n.name), '[]'::jsonb)
    into p_teaching
    from public.user_skills us join public.skill_nodes n on n.id = us.skill_id
    where us.user_id = p_user and us.kind = 'teach'::public.skill_kind;
  select coalesce(jsonb_agg(jsonb_build_object(
      'skill', n.name, 'path', n.path::text,
      'note', case when us.note_approved then us.note else null end
    ) order by n.name), '[]'::jsonb)
    into p_learning
    from public.user_skills us join public.skill_nodes n on n.id = us.skill_id
    where us.user_id = p_user and us.kind = 'learn'::public.skill_kind;
  select coalesce(jsonb_agg(jsonb_build_object('media', sc.media_url, 'kind', sc.media_kind::text,
             'thumb', sc.thumbnail_url, 'skill', n.name, 'caption', sc.caption) order by sc.created_at), '[]'::jsonb)
    into p_showcases
    from public.skill_showcases sc left join public.skill_nodes n on n.id = sc.skill_id
    where sc.user_id = p_user;
end $$;


ALTER FUNCTION "public"."get_public_profile"("p_user" "uuid", OUT "p_name" "text", OUT "p_role" "text", OUT "p_bio" "text", OUT "p_avatar" "text", OUT "p_languages" "text", OUT "p_styles" "text", OUT "p_availability" "jsonb", OUT "p_teaching" "jsonb", OUT "p_learning" "jsonb", OUT "p_showcases" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.profiles (
    id,
    first_name,
    last_name,
    email
  )
  values (
    new.id,
    new.raw_user_meta_data ->> 'first_name',
    new.raw_user_meta_data ->> 'last_name',
    lower(new.email)
  );

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin
  );
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_notifications"("p_unread_only" boolean DEFAULT false, "p_limit" integer DEFAULT 30) RETURNS TABLE("id" "uuid", "kind" "text", "payload" "jsonb", "read_at" timestamp with time zone, "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select n.id, n.kind, n.payload, n.read_at, n.created_at
  from public.notifications n
  where n.user_id = auth.uid() and (not p_unread_only or n.read_at is null)
  order by n.created_at desc limit p_limit
$$;


ALTER FUNCTION "public"."list_notifications"("p_unread_only" boolean, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_messages_read"("p_connection" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Not authenticated'; end if;
  update public.connections
    set requester_read_at = case when requester_id = me then now() else requester_read_at end,
        recipient_read_at = case when requester_id = me then recipient_read_at else now() end
    where id = p_connection and (requester_id = me or recipient_id = me);
end $$;


ALTER FUNCTION "public"."mark_messages_read"("p_connection" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_notifications_read"() RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.notifications set read_at = now() where user_id = auth.uid() and read_at is null
$$;


ALTER FUNCTION "public"."mark_notifications_read"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."match_candidates"("p_user" "uuid", "p_target" "public"."embed_role", "p_limit" integer, "p_w_skills" real, "p_w_context" real) RETURNS TABLE("candidate_id" "uuid", "bi_score" real)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
with seeker as (
  select (case when p_target = 'mentor' then 'learner' else 'mentor' end)::public.embed_role as s_role
),
target_kind as (
  select (case when p_target = 'mentor' then 'teach' else 'learn' end)::public.skill_kind as k
),
blocked as (
  select blocked_id as uid from public.blocks where blocker_id = p_user
  union
  select blocker_id as uid from public.blocks where blocked_id = p_user
),
s_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'skills'::public.embed_field_group
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
),
s_sc as (
  select e.user_id, (1 - extensions.cosine_distance(s_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join s_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'skills'::public.embed_field_group
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
),
c_sc as (
  select e.user_id, (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'context'::public.embed_field_group
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
),
fallback as (
  select distinct us.user_id
  from public.user_skills us
  cross join target_kind tk
  join public.profiles pf on pf.id = us.user_id and pf.has_completed_onboarding
  where us.kind = tk.k
    and us.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = us.user_id)
  limit 200
),
u as (
  select user_id from s_sc
  union
  select user_id from c_sc
  union
  select user_id from fallback
)
select u.user_id,
  (p_w_skills * coalesce(s_sc.sim, 0) + p_w_context * coalesce(c_sc.sim, 0))::real
from u
left join s_sc on s_sc.user_id = u.user_id
left join c_sc on c_sc.user_id = u.user_id
join public.profiles pf on pf.id = u.user_id and pf.has_completed_onboarding
where not exists (select 1 from blocked b where b.uid = u.user_id)
  and (
    coalesce(auth.role(), '') = 'service_role'
    or p_user = auth.uid()
  )
order by 2 desc
limit p_limit;
$$;


ALTER FUNCTION "public"."match_candidates"("p_user" "uuid", "p_target" "public"."embed_role", "p_limit" integer, "p_w_skills" real, "p_w_context" real) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_feedback_status"("p_connection" "uuid") RETURNS TABLE("gate_open" boolean, "already_rated" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.feedback_gate_open(p_connection),
    exists (
      select 1 from public.feedback f
      where f.connection_id = p_connection and f.rater_id = auth.uid()
    )
  where exists (
    select 1 from public.connections c
    where c.id = p_connection
      and (c.requester_id = auth.uid() or c.recipient_id = auth.uid())
  );
$$;


ALTER FUNCTION "public"."my_feedback_status"("p_connection" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."node_label"("raw" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select nullif(btrim(
    regexp_replace(
      regexp_replace(
        replace(lower(btrim(regexp_replace(btrim(raw), '\s+', ' ', 'g'))), ' ', '_'),
        '[^a-z0-9_]', '', 'g'),
      '_+', '_', 'g'),
  '_'), '_')
$$;


ALTER FUNCTION "public"."node_label"("raw" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify"("p_user" "uuid", "p_kind" "text", "p_payload" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.notifications (user_id, kind, payload) values (p_user, p_kind, p_payload);
end $$;


ALTER FUNCTION "public"."notify"("p_user" "uuid", "p_kind" "text", "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profile_match_view"("p_users" "uuid"[]) RETURNS TABLE("user_id" "uuid", "name" "text", "role" "text", "learner_text" "text", "mentor_text" "text", "learner_context" "text", "mentor_context" "text")
    LANGUAGE "sql" STABLE
    AS $$
with pas as (
  select u.uid as user_id, b.role, b.field_group, b.source_text
  from unnest(p_users) as u(uid)
  cross join lateral build_profile_passages(u.uid) b
),
summ as (
  select p.id as user_id,
    coalesce(p.display_name, '') as name,
    p.role::text as role
  from public.profiles p where p.id = any (p_users)
)
select s.user_id, s.name, s.role,
  coalesce((select source_text from pas pa where pa.user_id = s.user_id and pa.role = 'learner'::public.embed_role and pa.field_group = 'skills'::public.embed_field_group), ''),
  coalesce((select source_text from pas pa where pa.user_id = s.user_id and pa.role = 'mentor'::public.embed_role and pa.field_group = 'skills'::public.embed_field_group), ''),
  coalesce((select source_text from pas pa where pa.user_id = s.user_id and pa.role = 'learner'::public.embed_role and pa.field_group = 'context'::public.embed_field_group), ''),
  coalesce((select source_text from pas pa where pa.user_id = s.user_id and pa.role = 'mentor'::public.embed_role and pa.field_group = 'context'::public.embed_field_group), '')
from summ s
$$;


ALTER FUNCTION "public"."profile_match_view"("p_users" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profiles_search_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.search_vector := to_tsvector('english',
    coalesce(new.first_name,'') || ' ' || coalesce(new.last_name,'') || ' ' ||
    coalesce(new.bio,'') || ' ' ||
    array_to_string(coalesce(new.learning_skills, '{}'::text[]), ' ') || ' ' ||
    array_to_string(coalesce(new.teaching_skills, '{}'::text[]), ' ') || ' ' ||
    array_to_string(coalesce(new.skill_categories, '{}'::text[]), ' '));
  return new;
end $$;


ALTER FUNCTION "public"."profiles_search_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rebuild_skill_array"("p_user" "uuid", "p_kind" "public"."skill_kind", "p_existing" "text"[], "p_exclude" "uuid" DEFAULT NULL::"uuid") RETURNS "text"[]
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  select coalesce(array_agg(distinct x order by x), '{}'::text[])
  from (
    select n.name as x
    from public.user_skills us
    join public.skill_nodes n on n.id = us.skill_id
    where us.user_id = p_user and us.kind = p_kind
    union
    select a.name
    from unnest(coalesce(p_existing, '{}'::text[])) a
    where (p_exclude is null
           or public.resolve_skill_node(a.name) is distinct from p_exclude)
      and (
        public.resolve_skill_node(a.name) is null
        or public.resolve_skill_node(a.name) not in (
          select us.skill_id from public.user_skills us
          where us.user_id = p_user and us.kind = p_kind
        )
      )
  ) q;
$$;


ALTER FUNCTION "public"."rebuild_skill_array"("p_user" "uuid", "p_kind" "public"."skill_kind", "p_existing" "text"[], "p_exclude" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_user"("p_target" "uuid", "p_reason" "text", "p_details" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_target then raise exception 'You cannot report yourself'; end if;
  insert into public.reports (reporter_id, reported_id, reason, details) values (me, p_target, btrim(p_reason), p_details);
end $$;


ALTER FUNCTION "public"."report_user"("p_target" "uuid", "p_reason" "text", "p_details" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_skill_node"("p_name" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_id uuid;
  v_slug text;
  v_tokens text[];
begin
  if v_name = '' then
    return null;
  end if;

  -- exact display name (approved preferred, then usage)
  select n.id into v_id
  from public.skill_nodes n
  where n.is_leaf
    and lower(n.name) = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  -- full dotted ltree path
  select n.id into v_id
  from public.skill_nodes n
  where n.is_leaf
    and n.path::text = lower(v_name)
  order by (n.status = 'approved') desc, n.usage_count desc
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  -- trailing taxonomy slug, e.g. cooking_pinakbet
  v_slug := btrim(lower(regexp_replace(v_name, '[^a-zA-Z0-9]+', '_', 'g')), '_');
  if v_slug <> '' then
    select n.id into v_id
    from public.skill_nodes n
    where n.is_leaf
      and split_part(n.path::text, '.', -1) = v_slug
    order by (n.status = 'approved') desc, n.usage_count desc
    limit 1;
    if v_id is not null then
      return v_id;
    end if;
  end if;

  -- token-set match catches word-order variants such as
  -- "Adobo Cooking" -> "Cooking Adobo"
  select array_agg(t order by t) into v_tokens
  from unnest(regexp_split_to_array(lower(v_name), '[^a-z0-9]+')) t
  where t <> '';
  if v_tokens is not null then
    select n.id into v_id
    from public.skill_nodes n
    where n.is_leaf
      and n.status = 'approved'
      and (
        select array_agg(t order by t)
        from unnest(regexp_split_to_array(lower(n.name), '[^a-z0-9]+')) t
        where t <> ''
      ) = v_tokens
    order by n.usage_count desc
    limit 1;
  end if;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."resolve_skill_node"("p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."respond_connection_request"("p_connection" "uuid", "p_accept" boolean) RETURNS TABLE("new_status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid(); r public.connections%rowtype;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  select * into r from public.connections where id = p_connection;
  if not found then raise exception 'Connection not found'; end if;
  if r.recipient_id <> me then raise exception 'Only the recipient can respond'; end if;
  if r.status <> 'pending' then raise exception 'Request already handled'; end if;
  update public.connections
    set status = case when p_accept then 'accepted'::public.conn_status else 'declined'::public.conn_status end,
        responded_at = now()
    where id = p_connection returning * into r;
  perform public.notify(r.requester_id,
    case when p_accept then 'request_accepted' else 'request_declined' end,
    jsonb_build_object('connection_id', r.id, 'responder_id', me));
  return query select r.status::text;
end $$;


ALTER FUNCTION "public"."respond_connection_request"("p_connection" "uuid", "p_accept" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_user_skills"("p_learning" "jsonb" DEFAULT NULL::"jsonb", "p_teaching" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_uid uuid := auth.uid();
  v_kind public.skill_kind;
  v_input jsonb;
  v_rec jsonb;
  v_name text;
  v_note text;
  v_has_note boolean;
  v_approved_now boolean;
  v_node uuid;
  v_keep_learn uuid[] := '{}';
  v_keep_teach uuid[] := '{}';
  v_notes_learn jsonb := '{}'::jsonb;
  v_notes_teach jsonb := '{}'::jsonb;
  v_unotes_learn jsonb := '{}'::jsonb;
  v_unotes_teach jsonb := '{}'::jsonb;
  v_unresolved_learn text[] := '{}';
  v_unresolved_teach text[] := '{}';
  v_cleared_learn text[] := '{}';
  v_cleared_teach text[] := '{}';
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if jsonb_typeof(p_learning) is not null and jsonb_typeof(p_learning) <> 'array' then
    raise exception 'p_learning must be a JSON array';
  end if;
  if jsonb_typeof(p_teaching) is not null and jsonb_typeof(p_teaching) <> 'array' then
    raise exception 'p_teaching must be a JSON array';
  end if;
  if jsonb_array_length(p_learning) > 50 or jsonb_array_length(p_teaching) > 50 then
    raise exception 'too many skills';
  end if;

  -- Pass 1: resolve everything and collect the target sets. No writes yet, so
  -- replacing one of three skills does not trip enforce_skill_caps.
  for v_kind, v_input in
    select 'learn'::public.skill_kind, p_learning where p_learning is not null
    union all
    select 'teach'::public.skill_kind, p_teaching where p_teaching is not null
  loop
    for v_rec in select value from jsonb_array_elements(v_input) loop
      if jsonb_typeof(v_rec) <> 'object' then
        raise exception 'each skill must be an object with name/note';
      end if;
      if not (v_rec ? 'name')
         or jsonb_typeof(v_rec->'name') is distinct from 'string' then
        raise exception 'skill name must be a string';
      end if;
      v_name := btrim(v_rec->>'name');
      if v_name = '' then
        raise exception 'skill name is required';
      end if;
      if length(v_name) > 80 then
        raise exception 'skill name too long (max 80 characters)';
      end if;

      v_has_note := v_rec ? 'note';
      v_note := left(btrim(coalesce(v_rec->>'note', '')), 150);

      v_node := public.resolve_skill_node(v_name);
      if v_node is null then
        if v_kind = 'learn' then
          if not (v_name = any(v_unresolved_learn)) then
            v_unresolved_learn := array_append(v_unresolved_learn, v_name);
          end if;
          if v_has_note then
            if v_note = '' then
              v_unotes_learn := v_unotes_learn - v_name;
              v_cleared_learn := array_append(v_cleared_learn, v_name);
            else
              v_cleared_learn := array_remove(v_cleared_learn, v_name);
              v_unotes_learn := jsonb_set(
                v_unotes_learn, array[v_name], to_jsonb(v_note)
              );
            end if;
          end if;
        else
          if not (v_name = any(v_unresolved_teach)) then
            v_unresolved_teach := array_append(v_unresolved_teach, v_name);
          end if;
          if v_has_note then
            if v_note = '' then
              v_unotes_teach := v_unotes_teach - v_name;
              v_cleared_teach := array_append(v_cleared_teach, v_name);
            else
              v_cleared_teach := array_remove(v_cleared_teach, v_name);
              v_unotes_teach := jsonb_set(
                v_unotes_teach, array[v_name], to_jsonb(v_note)
              );
            end if;
          end if;
        end if;
        continue;
      end if;

      -- Promote a private custom note if this name now resolves to a node.
      if not v_has_note then
        select note into v_note
        from public.user_skill_notes
        where user_id = v_uid and kind = v_kind and name = v_name;
        if found then
          v_has_note := true;
        end if;
      end if;

      if v_kind = 'learn' then
        if not (v_node = any(v_keep_learn)) then
          v_keep_learn := array_append(v_keep_learn, v_node);
        end if;
        if v_has_note then
          v_notes_learn := jsonb_set(
            v_notes_learn, array[v_node::text], to_jsonb(v_note)
          );
        end if;
      else
        if not (v_node = any(v_keep_teach)) then
          v_keep_teach := array_append(v_keep_teach, v_node);
        end if;
        if v_has_note then
          v_notes_teach := jsonb_set(
            v_notes_teach, array[v_node::text], to_jsonb(v_note)
          );
        end if;
      end if;
    end loop;
  end loop;

  -- Pass 2: delete the complement first, then write the kept rows.
  if coalesce(array_length(v_keep_learn, 1), 0) +
     coalesce(array_length(v_unresolved_learn, 1), 0) > 3 then
    raise exception 'Skill cap reached: maximum 3 skills of kind "learn"';
  end if;
  if coalesce(array_length(v_keep_teach, 1), 0) +
     coalesce(array_length(v_unresolved_teach, 1), 0) > 3 then
    raise exception 'Skill cap reached: maximum 3 skills of kind "teach"';
  end if;

  if p_learning is not null then
    delete from public.user_skills us
    where us.user_id = v_uid
      and us.kind = 'learn'
      and not (us.skill_id = any(v_keep_learn));
  end if;

  if p_teaching is not null then
    delete from public.user_skills us
    where us.user_id = v_uid
      and us.kind = 'teach'
      and not (us.skill_id = any(v_keep_teach));
  end if;

  foreach v_node in array v_keep_learn loop
    if v_notes_learn ? v_node::text then
      v_note := v_notes_learn->>v_node::text;
      update public.user_skills
      set note = nullif(v_note, ''),
          note_approved = case
            when note is distinct from nullif(v_note, '') then false
            else note_approved
          end,
          updated_at = now()
      where user_id = v_uid and skill_id = v_node and kind = 'learn';
    else
      update public.user_skills
      set updated_at = now()
      where user_id = v_uid and skill_id = v_node and kind = 'learn';
    end if;
    if not found then
      insert into public.user_skills
        (user_id, skill_id, kind, note, note_approved)
      values (
        v_uid,
        v_node,
        'learn',
        case when v_notes_learn ? v_node::text
          then nullif(v_notes_learn->>v_node::text, '') else null end,
        false
      );
    end if;
  end loop;

  foreach v_node in array v_keep_teach loop
    if v_notes_teach ? v_node::text then
      v_note := v_notes_teach->>v_node::text;
      update public.user_skills
      set note = nullif(v_note, ''),
          note_approved = case
            when note is distinct from nullif(v_note, '') then false
            else note_approved
          end,
          updated_at = now()
      where user_id = v_uid and skill_id = v_node and kind = 'teach';
    else
      update public.user_skills
      set updated_at = now()
      where user_id = v_uid and skill_id = v_node and kind = 'teach';
    end if;
    if not found then
      insert into public.user_skills
        (user_id, skill_id, kind, note, note_approved)
      values (
        v_uid,
        v_node,
        'teach',
        case when v_notes_teach ? v_node::text
          then nullif(v_notes_teach->>v_node::text, '') else null end,
        false
      );
    end if;
  end loop;

  -- The user_skills trigger writes canonical names into the arrays. Keep
  -- unresolved custom names in the arrays so the editor does not lose them.
  update public.profiles p
  set learning_skills = case
        when p_learning is null then p.learning_skills
        else (
          select coalesce(array_agg(distinct x order by x), '{}'::text[])
          from (
            select n.name as x
            from public.user_skills us
            join public.skill_nodes n on n.id = us.skill_id
            where us.user_id = v_uid and us.kind = 'learn'
            union
            select unnest(v_unresolved_learn)
          ) q
        )
      end,
      teaching_skills = case
        when p_teaching is null then p.teaching_skills
        else (
          select coalesce(array_agg(distinct x order by x), '{}'::text[])
          from (
            select n.name as x
            from public.user_skills us
            join public.skill_nodes n on n.id = us.skill_id
            where us.user_id = v_uid and us.kind = 'teach'
            union
            select unnest(v_unresolved_teach)
          ) q
        )
      end
  where p.id = v_uid;

  -- Queue changed resolved notes and store unresolved notes privately.
  if p_learning is not null then
    for v_name, v_note, v_node in
      select n.name, j.value, n.id
      from jsonb_each_text(v_notes_learn) as j(key, value)
      join public.skill_nodes n on n.id = j.key::uuid
    loop
      if v_note = '' then
        delete from public.note_moderation_queue
        where user_id = v_uid and kind = 'learn' and name = v_name;
      else
        select note_approved into v_approved_now
        from public.user_skills
        where user_id = v_uid and skill_id = v_node and kind = 'learn';
        if not coalesce(v_approved_now, false) then
          insert into public.note_moderation_queue
            (user_id, kind, name, skill_id, note, note_hash, status, attempts)
          values (v_uid, 'learn', v_name, v_node, v_note, md5(v_note), 'pending', 0)
          on conflict (user_id, kind, name) do update
            set skill_id = excluded.skill_id,
                note = excluded.note,
                note_hash = excluded.note_hash,
                status = 'pending',
                attempts = 0,
                last_error = null,
                updated_at = now();
        end if;
      end if;
    end loop;

    for v_name, v_note in select key, value from jsonb_each_text(v_unotes_learn) loop
      if v_note = '' then
        delete from public.user_skill_notes
        where user_id = v_uid and kind = 'learn' and name = v_name;
        delete from public.note_moderation_queue
        where user_id = v_uid and kind = 'learn' and name = v_name
          and skill_id is null;
      else
        insert into public.user_skill_notes
          (user_id, kind, name, note, updated_at)
        values (v_uid, 'learn', v_name, v_note, now())
        on conflict (user_id, kind, name) do update
          set note = excluded.note, updated_at = now();

        insert into public.note_moderation_queue
          (user_id, kind, name, skill_id, note, note_hash, status, attempts)
        values (v_uid, 'learn', v_name, null, v_note, md5(v_note), 'pending', 0)
        on conflict (user_id, kind, name) do update
          set skill_id = null,
              note = excluded.note,
              note_hash = excluded.note_hash,
              status = 'pending',
              attempts = 0,
              last_error = null,
              updated_at = now();
      end if;
    end loop;

    foreach v_name in array v_cleared_learn loop
      delete from public.user_skill_notes
      where user_id = v_uid and kind = 'learn' and name = v_name;
      delete from public.note_moderation_queue
      where user_id = v_uid and kind = 'learn' and name = v_name
        and skill_id is null;
    end loop;

    delete from public.user_skill_notes n
    where n.user_id = v_uid and n.kind = 'learn'
      and not (n.name = any(v_unresolved_learn));

    delete from public.note_moderation_queue q
    where q.user_id = v_uid and q.kind = 'learn' and q.skill_id is null
      and not (q.name = any(v_unresolved_learn));

    delete from public.note_moderation_queue q
    using public.skill_nodes n
    where q.user_id = v_uid and q.kind = 'learn' and q.skill_id = n.id
      and not (q.skill_id = any(v_keep_learn));
  end if;

  if p_teaching is not null then
    for v_name, v_note, v_node in
      select n.name, j.value, n.id
      from jsonb_each_text(v_notes_teach) as j(key, value)
      join public.skill_nodes n on n.id = j.key::uuid
    loop
      if v_note = '' then
        delete from public.note_moderation_queue
        where user_id = v_uid and kind = 'teach' and name = v_name;
      else
        select note_approved into v_approved_now
        from public.user_skills
        where user_id = v_uid and skill_id = v_node and kind = 'teach';
        if not coalesce(v_approved_now, false) then
          insert into public.note_moderation_queue
            (user_id, kind, name, skill_id, note, note_hash, status, attempts)
          values (v_uid, 'teach', v_name, v_node, v_note, md5(v_note), 'pending', 0)
          on conflict (user_id, kind, name) do update
            set skill_id = excluded.skill_id,
                note = excluded.note,
                note_hash = excluded.note_hash,
                status = 'pending',
                attempts = 0,
                last_error = null,
                updated_at = now();
        end if;
      end if;
    end loop;

    for v_name, v_note in select key, value from jsonb_each_text(v_unotes_teach) loop
      if v_note = '' then
        delete from public.user_skill_notes
        where user_id = v_uid and kind = 'teach' and name = v_name;
        delete from public.note_moderation_queue
        where user_id = v_uid and kind = 'teach' and name = v_name
          and skill_id is null;
      else
        insert into public.user_skill_notes
          (user_id, kind, name, note, updated_at)
        values (v_uid, 'teach', v_name, v_note, now())
        on conflict (user_id, kind, name) do update
          set note = excluded.note, updated_at = now();

        insert into public.note_moderation_queue
          (user_id, kind, name, skill_id, note, note_hash, status, attempts)
        values (v_uid, 'teach', v_name, null, v_note, md5(v_note), 'pending', 0)
        on conflict (user_id, kind, name) do update
          set skill_id = null,
              note = excluded.note,
              note_hash = excluded.note_hash,
              status = 'pending',
              attempts = 0,
              last_error = null,
              updated_at = now();
      end if;
    end loop;

    foreach v_name in array v_cleared_teach loop
      delete from public.user_skill_notes
      where user_id = v_uid and kind = 'teach' and name = v_name;
      delete from public.note_moderation_queue
      where user_id = v_uid and kind = 'teach' and name = v_name
        and skill_id is null;
    end loop;

    delete from public.user_skill_notes n
    where n.user_id = v_uid and n.kind = 'teach'
      and not (n.name = any(v_unresolved_teach));

    delete from public.note_moderation_queue q
    where q.user_id = v_uid and q.kind = 'teach' and q.skill_id is null
      and not (q.name = any(v_unresolved_teach));

    delete from public.note_moderation_queue q
    using public.skill_nodes n
    where q.user_id = v_uid and q.kind = 'teach' and q.skill_id = n.id
      and not (q.skill_id = any(v_keep_teach));
  end if;

  return jsonb_build_object(
    'learning_unresolved', to_jsonb(v_unresolved_learn),
    'teaching_unresolved', to_jsonb(v_unresolved_teach)
  );
end;
$$;


ALTER FUNCTION "public"."save_user_skills"("p_learning" "jsonb", "p_teaching" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_profiles"("p_query" "text", "p_limit" integer DEFAULT 20) RETURNS TABLE("user_id" "uuid", "name" "text", "role" "text", "avatar_url" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select p.id, coalesce(p.display_name,''), p.role::text, p.avatar_url
  from public.profiles p
  where p.has_completed_onboarding and p.id <> auth.uid()
    and p.search_vector @@ websearch_to_tsquery('english', p_query)
  order by ts_rank(p.search_vector, websearch_to_tsquery('english', p_query)) desc
  limit p_limit
$$;


ALTER FUNCTION "public"."search_profiles"("p_query" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_connection_request"("p_recipient" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid(); conn uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_recipient then raise exception 'You cannot connect with yourself'; end if;
  if public.blocked_between(me, p_recipient) then raise exception 'Cannot connect with this user'; end if;
  if not exists (select 1 from public.profiles where id = p_recipient and has_completed_onboarding) then
    raise exception 'Recipient profile is not ready';
  end if;
  select id into conn from public.connections
  where (requester_id = me and recipient_id = p_recipient) or (requester_id = p_recipient and recipient_id = me);
  if conn is not null then
    update public.connections set status = 'pending', requester_id = me, recipient_id = p_recipient, responded_at = null
    where id = conn and status = 'declined';
    return conn;
  end if;
  insert into public.connections (requester_id, recipient_id) values (me, p_recipient) returning id into conn;
  perform public.notify(p_recipient, 'connection_request', jsonb_build_object('connection_id', conn, 'requester_id', me));
  return conn;
end $$;


ALTER FUNCTION "public"."send_connection_request"("p_recipient" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_message"("p_connection" "uuid", "p_body" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid(); c public.connections%rowtype; mid uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  select * into c from public.connections where id = p_connection;
  if not found then raise exception 'Connection not found'; end if;
  if c.status <> 'accepted' then raise exception 'Chat is locked until the connection is accepted'; end if;
  if c.requester_id <> me and c.recipient_id <> me then raise exception 'Not a participant'; end if;
  insert into public.messages (connection_id, sender_id, body) values (p_connection, me, btrim(p_body))
    returning id into mid;
  update public.connections
    set requester_read_at = case when requester_id = me then now() else requester_read_at end,
        recipient_read_at = case when requester_id = me then recipient_read_at else now() end
    where id = p_connection;
  perform public.check_feedback_gate(p_connection);
  return mid;
end $$;


ALTER FUNCTION "public"."send_message"("p_connection" "uuid", "p_body" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."skill_node_path"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare p extensions.ltree; d smallint;
begin
  if new.parent_id is null then
    new.path := public.node_label(new.name)::extensions.ltree;
    new.depth := 1;
  else
    select path, depth into p, d from public.skill_nodes where id = new.parent_id;
    if p is null then raise exception 'parent node not found'; end if;
    new.path := (p::text || '.' || public.node_label(new.name))::extensions.ltree;
    new.depth := d + 1;
  end if;
  return new;
end $$;


ALTER FUNCTION "public"."skill_node_path"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."skill_slug"("raw" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select nullif(regexp_replace(
    replace(btrim(regexp_replace(btrim(raw), '\s+', ' ', 'g')), ' ', '-'),
    '[^a-z0-9-]', '', 'g'), '-')
$$;


ALTER FUNCTION "public"."skill_slug"("raw" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_feedback"("p_connection" "uuid", "p_clarity" smallint, "p_reliability" smallint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid(); c public.connections%rowtype; other uuid;
begin
  if me is null then raise exception 'Not authenticated'; end if;
  select * into c from public.connections where id = p_connection;
  if not found then raise exception 'Connection not found'; end if;
  if c.status <> 'accepted' then raise exception 'Feedback requires an accepted connection'; end if;
  if c.requester_id <> me and c.recipient_id <> me then raise exception 'Not a participant'; end if;
  if not public.feedback_gate_open(p_connection) then
    raise exception 'Feedback unlocks after 15 messages in this connection (FR-12)';
  end if;
  other := case when c.requester_id = me then c.recipient_id else c.requester_id end;
  insert into public.feedback (connection_id, rater_id, ratee_id, clarity_of_instruction, reliability)
    values (p_connection, me, other, p_clarity, p_reliability)
    on conflict (connection_id, rater_id) do update
      set clarity_of_instruction = excluded.clarity_of_instruction,
          reliability = excluded.reliability;
end $$;


ALTER FUNCTION "public"."submit_feedback"("p_connection" "uuid", "p_clarity" smallint, "p_reliability" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_profile_email"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  update public.profiles
  set email = new.email,
      updated_at = now()
  where id = new.id;
  return new;
end;
$$;


ALTER FUNCTION "public"."sync_profile_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_profile_skill_arrays"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  uid uuid;
  v_kinds public.skill_kind[];
  v_exclude uuid := null;
begin
  if tg_op = 'DELETE' then
    uid := old.user_id;
    v_kinds := array[old.kind];
    v_exclude := old.skill_id;
  else
    uid := new.user_id;
    if tg_op = 'UPDATE' and new.kind <> old.kind then
      v_kinds := array[old.kind, new.kind];
      v_exclude := old.skill_id;
    else
      v_kinds := array[new.kind];
    end if;
  end if;

  update public.profiles p
  set learning_skills = case
        when 'learn'::public.skill_kind = any(v_kinds)
          then public.rebuild_skill_array(uid, 'learn', p.learning_skills, v_exclude)
        else p.learning_skills
      end,
      teaching_skills = case
        when 'teach'::public.skill_kind = any(v_kinds)
          then public.rebuild_skill_array(uid, 'teach', p.teaching_skills, v_exclude)
        else p.teaching_skills
      end
  where p.id = uid;

  -- A changed user must not stay hidden in cached decks.
  delete from public.match_cache where user_id = uid or candidate_id = uid;
  return null;
end;
$$;


ALTER FUNCTION "public"."sync_profile_skill_arrays"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."taxonomy_visible"("p_root_path" "text" DEFAULT NULL::"text") RETURNS TABLE("id" "uuid", "name" "text", "path" "text", "depth" smallint, "is_leaf" boolean, "usage_count" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions'
    AS $$
  select n.id, n.name, n.path::text, n.depth, n.is_leaf, n.usage_count
  from public.skill_nodes n
  where (n.status = 'approved' or n.submitted_by = auth.uid())
    and (p_root_path is null or (p_root_path::extensions.ltree @> n.path))
    and (n.depth <= 2 or n.is_leaf)
  order by n.path
$$;


ALTER FUNCTION "public"."taxonomy_visible"("p_root_path" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unblock_user"("p_target" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Not authenticated'; end if;
  delete from public.blocks where blocker_id = me and blocked_id = p_target;
end $$;


ALTER FUNCTION "public"."unblock_user"("p_target" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unmatch_connection"("p_connection" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    -- Idempotent: a retry after a successful unmatch is a no-op.
    return;
  end if;

  if c.requester_id <> me and c.recipient_id <> me then
    raise exception 'Not a participant';
  end if;

  if c.status <> 'accepted' then
    raise exception 'Only accepted connections can be unmatched';
  end if;

  delete from public.connections where id = p_connection;
end;
$$;


ALTER FUNCTION "public"."unmatch_connection"("p_connection" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_node_usage"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare sid uuid;
begin
  sid := coalesce(new.skill_id, old.skill_id);
  update public.skill_nodes s set usage_count =
    (select count(*) from public.user_skills us where us.skill_id = sid)
  where s.id = sid;
  return null;
end $$;


ALTER FUNCTION "public"."update_node_usage"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_skill_usage"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare sid uuid;
begin
  sid := coalesce(new.skill_id, old.skill_id);
  update public.skills s set usage_count =
    (select count(*) from public.user_skills us where us.skill_id = sid)
  where s.id = sid;
  return null;
end $$;


ALTER FUNCTION "public"."update_skill_usage"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blocks" (
    "blocker_id" "uuid" NOT NULL,
    "blocked_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."blocks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."connections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "requester_id" "uuid" NOT NULL,
    "recipient_id" "uuid" NOT NULL,
    "status" "public"."conn_status" DEFAULT 'pending'::"public"."conn_status" NOT NULL,
    "requester_read_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "recipient_read_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "responded_at" timestamp with time zone,
    CONSTRAINT "connections_check" CHECK (("requester_id" <> "recipient_id"))
);


ALTER TABLE "public"."connections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "connection_id" "uuid" NOT NULL,
    "rater_id" "uuid" NOT NULL,
    "ratee_id" "uuid" NOT NULL,
    "clarity_of_instruction" smallint NOT NULL,
    "reliability" smallint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "feedback_check" CHECK (("rater_id" <> "ratee_id")),
    CONSTRAINT "feedback_clarity_of_instruction_check" CHECK ((("clarity_of_instruction" >= 1) AND ("clarity_of_instruction" <= 5))),
    CONSTRAINT "feedback_reliability_check" CHECK ((("reliability" >= 1) AND ("reliability" <= 5)))
);


ALTER TABLE "public"."feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."integration_secrets" (
    "name" "text" NOT NULL,
    "value" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."integration_secrets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."match_cache" (
    "user_id" "uuid" NOT NULL,
    "as_role" "public"."embed_role" NOT NULL,
    "candidate_id" "uuid" NOT NULL,
    "rank" integer NOT NULL,
    "bi_score" real,
    "rerank_score_a" real,
    "rerank_score_b" real,
    "reciprocal_score" real NOT NULL,
    "calibrated_score" real NOT NULL,
    "pipeline_mode" "text" DEFAULT 'full'::"text" NOT NULL,
    "model_name" "text" NOT NULL,
    "config_version" integer NOT NULL,
    "refreshed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."match_cache" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "connection_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "messages_body_check" CHECK ((("btrim"("body") <> ''::"text") AND ("length"("body") <= 4000)))
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "payload" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notifications_kind_check" CHECK (("kind" = ANY (ARRAY['connection_request'::"text", 'request_accepted'::"text", 'request_declined'::"text", 'feedback_ready'::"text", 'skill_moderation'::"text"])))
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pipeline_config" (
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL,
    "description" "text",
    "config_version" integer DEFAULT 1 NOT NULL,
    "updated_by" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pipeline_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profile_embeddings" (
    "user_id" "uuid" NOT NULL,
    "role" "public"."embed_role" NOT NULL,
    "field_group" "public"."embed_field_group" NOT NULL,
    "source_text" "text" NOT NULL,
    "source_hash" "text" NOT NULL,
    "model_name" "text" DEFAULT 'nvidia/llama-nemotron-embed-1b-v2'::"text" NOT NULL,
    "embedding" "extensions"."vector"(1024) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "input_type" "text" DEFAULT 'passage'::"text" NOT NULL
);


ALTER TABLE "public"."profile_embeddings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "first_name" "text" DEFAULT ''::"text",
    "last_name" "text" DEFAULT ''::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email" "text",
    "role" "public"."user_role" DEFAULT 'both'::"public"."user_role" NOT NULL,
    "learning_skills" "text"[] DEFAULT '{}'::"text"[],
    "teaching_skills" "text"[] DEFAULT '{}'::"text"[],
    "learning_styles" "text"[] DEFAULT '{}'::"text"[],
    "languages" "text"[] DEFAULT '{}'::"text"[],
    "availability" "jsonb" DEFAULT '{}'::"jsonb",
    "is_profile_completed" boolean DEFAULT false NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "has_completed_onboarding" boolean DEFAULT false,
    "bio" "text" DEFAULT ''::"text",
    "avatar_url" "text",
    "photos" "text"[] DEFAULT '{}'::"text"[],
    "teaching_skill_images" "jsonb" DEFAULT '{}'::"jsonb",
    "skill_categories" "text"[] DEFAULT '{}'::"text"[],
    "display_name" "text" GENERATED ALWAYS AS (NULLIF("btrim"(((COALESCE("first_name", ''::"text") || ' '::"text") || COALESCE("last_name", ''::"text"))), ''::"text")) STORED,
    "timezone" "text" DEFAULT 'Asia/Manila'::"text",
    "is_admin" boolean DEFAULT false NOT NULL,
    "search_vector" "tsvector"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rate_limits" (
    "subject" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "window_start" timestamp with time zone NOT NULL,
    "count" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."rate_limits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "reported_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "details" "text",
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "reports_check" CHECK (("reporter_id" <> "reported_id")),
    CONSTRAINT "reports_details_check" CHECK ((("details" IS NULL) OR ("length"("details") <= 4000))),
    CONSTRAINT "reports_reason_check" CHECK (("length"("reason") <= 2000)),
    CONSTRAINT "reports_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'reviewed'::"text", 'dismissed'::"text", 'actioned'::"text"])))
);


ALTER TABLE "public"."reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."skill_moderation_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "raw_input" "text" NOT NULL,
    "note" "text",
    "verdict" "jsonb" NOT NULL,
    "action" "text",
    "confidence" real,
    "model" "text",
    "prompt_version" "text",
    "config_version" integer,
    "cost_usd" real,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "stage" "text"
);


ALTER TABLE "public"."skill_moderation_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."skill_nodes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "parent_id" "uuid",
    "name" "text" NOT NULL,
    "path" "extensions"."ltree" NOT NULL,
    "depth" smallint DEFAULT 1 NOT NULL,
    "is_leaf" boolean DEFAULT false NOT NULL,
    "is_visible" boolean DEFAULT false NOT NULL,
    "origin" "public"."skill_origin" DEFAULT 'user_submitted'::"public"."skill_origin" NOT NULL,
    "status" "public"."skill_status" DEFAULT 'pending'::"public"."skill_status" NOT NULL,
    "submitted_by" "uuid",
    "usage_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "skill_nodes_depth_check" CHECK ((("depth" >= 1) AND ("depth" <= 10)))
);


ALTER TABLE "public"."skill_nodes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."skill_showcases" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "media_url" "text" NOT NULL,
    "media_kind" "public"."media_kind" DEFAULT 'image'::"public"."media_kind" NOT NULL,
    "thumbnail_url" "text",
    "caption" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "skill_id" "uuid"
);


ALTER TABLE "public"."skill_showcases" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_skill_notes" (
    "user_id" "uuid" NOT NULL,
    "kind" "public"."skill_kind" NOT NULL,
    "name" "text" NOT NULL,
    "note" "text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_skill_notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_skills" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "skill_id" "uuid" NOT NULL,
    "kind" "public"."skill_kind" NOT NULL,
    "note" "text",
    "tags" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "note_approved" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."user_skills" OWNER TO "postgres";


ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_pkey" PRIMARY KEY ("blocker_id", "blocked_id");



ALTER TABLE ONLY "public"."connections"
    ADD CONSTRAINT "connections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_connection_id_rater_id_key" UNIQUE ("connection_id", "rater_id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."integration_secrets"
    ADD CONSTRAINT "integration_secrets_pkey" PRIMARY KEY ("name");



ALTER TABLE ONLY "public"."match_cache"
    ADD CONSTRAINT "match_cache_pkey" PRIMARY KEY ("user_id", "as_role", "candidate_id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."note_moderation_queue"
    ADD CONSTRAINT "note_moderation_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."note_moderation_queue"
    ADD CONSTRAINT "note_moderation_queue_user_id_kind_name_key" UNIQUE ("user_id", "kind", "name");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pipeline_config"
    ADD CONSTRAINT "pipeline_config_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."profile_embeddings"
    ADD CONSTRAINT "profile_embeddings_pkey" PRIMARY KEY ("user_id", "role", "field_group", "input_type");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rate_limits"
    ADD CONSTRAINT "rate_limits_pkey" PRIMARY KEY ("subject", "action", "window_start");



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."skill_moderation_log"
    ADD CONSTRAINT "skill_moderation_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."skill_nodes"
    ADD CONSTRAINT "skill_nodes_path_key" UNIQUE ("path");



ALTER TABLE ONLY "public"."skill_nodes"
    ADD CONSTRAINT "skill_nodes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."skill_showcases"
    ADD CONSTRAINT "skill_showcases_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_skill_notes"
    ADD CONSTRAINT "user_skill_notes_pkey" PRIMARY KEY ("user_id", "kind", "name");



ALTER TABLE ONLY "public"."user_skills"
    ADD CONSTRAINT "user_skills_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_skills"
    ADD CONSTRAINT "user_skills_user_id_skill_id_kind_key" UNIQUE ("user_id", "skill_id", "kind");



CREATE INDEX "idx_blocks_blocked" ON "public"."blocks" USING "btree" ("blocked_id");



CREATE INDEX "idx_connections_recipient" ON "public"."connections" USING "btree" ("recipient_id", "status");



CREATE INDEX "idx_connections_requester" ON "public"."connections" USING "btree" ("requester_id", "status");



CREATE INDEX "idx_embed_retrieval" ON "public"."profile_embeddings" USING "btree" ("role", "field_group", "input_type");



CREATE INDEX "idx_embeddings_hnsw" ON "public"."profile_embeddings" USING "hnsw" ("embedding" "extensions"."vector_cosine_ops");



CREATE INDEX "idx_matchcache_rank" ON "public"."match_cache" USING "btree" ("user_id", "as_role", "rank");



CREATE INDEX "idx_messages_conn_time" ON "public"."messages" USING "btree" ("connection_id", "created_at");



CREATE INDEX "idx_nodes_leaf_visible" ON "public"."skill_nodes" USING "btree" ("is_leaf", "is_visible") WHERE "is_leaf";



CREATE INDEX "idx_nodes_parent" ON "public"."skill_nodes" USING "btree" ("parent_id");



CREATE INDEX "idx_nodes_path" ON "public"."skill_nodes" USING "gist" ("path");



CREATE INDEX "idx_notifications_unread" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC) WHERE ("read_at" IS NULL);



CREATE INDEX "idx_profiles_search" ON "public"."profiles" USING "gin" ("search_vector");



CREATE INDEX "idx_reports_open" ON "public"."reports" USING "btree" ("status") WHERE ("status" = 'open'::"text");



CREATE INDEX "idx_showcases_user" ON "public"."skill_showcases" USING "btree" ("user_id");



CREATE INDEX "idx_uskills_skill" ON "public"."user_skills" USING "btree" ("skill_id");



CREATE INDEX "idx_uskills_teach" ON "public"."user_skills" USING "btree" ("skill_id") WHERE ("kind" = 'teach'::"public"."skill_kind");



CREATE INDEX "idx_uskills_user" ON "public"."user_skills" USING "btree" ("user_id");



CREATE INDEX "note_queue_status_idx" ON "public"."note_moderation_queue" USING "btree" ("status", "created_at");



CREATE INDEX "rate_limits_window_idx" ON "public"."rate_limits" USING "btree" ("window_start");



CREATE UNIQUE INDEX "uq_connection_pair" ON "public"."connections" USING "btree" (LEAST("requester_id", "recipient_id"), GREATEST("requester_id", "recipient_id"));



CREATE UNIQUE INDEX "uq_showcase_user_skill" ON "public"."skill_showcases" USING "btree" ("user_id", "skill_id");



CREATE INDEX "user_skills_kind_idx" ON "public"."user_skills" USING "btree" ("kind");



CREATE OR REPLACE TRIGGER "trg_config_revision" AFTER INSERT OR DELETE OR UPDATE ON "public"."pipeline_config" FOR EACH ROW EXECUTE FUNCTION "public"."bump_config_revision"();



CREATE OR REPLACE TRIGGER "trg_leaf_only" BEFORE INSERT OR UPDATE OF "skill_id" ON "public"."user_skills" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_leaf_only"();



CREATE OR REPLACE TRIGGER "trg_node_path" BEFORE INSERT OR UPDATE OF "name", "parent_id" ON "public"."skill_nodes" FOR EACH ROW EXECUTE FUNCTION "public"."skill_node_path"();



CREATE OR REPLACE TRIGGER "trg_node_usage" AFTER INSERT OR DELETE OR UPDATE OF "skill_id" ON "public"."user_skills" FOR EACH ROW EXECUTE FUNCTION "public"."update_node_usage"();



CREATE OR REPLACE TRIGGER "trg_profiles_search" BEFORE INSERT OR UPDATE OF "first_name", "last_name", "bio", "learning_skills", "teaching_skills", "skill_categories" ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."profiles_search_update"();



CREATE OR REPLACE TRIGGER "trg_skill_caps" BEFORE INSERT OR UPDATE OF "user_id", "skill_id", "kind" ON "public"."user_skills" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_skill_caps"();



CREATE OR REPLACE TRIGGER "trg_sync_arrays" AFTER INSERT OR DELETE OR UPDATE OF "user_id", "skill_id", "kind" ON "public"."user_skills" FOR EACH ROW EXECUTE FUNCTION "public"."sync_profile_skill_arrays"();



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."connections"
    ADD CONSTRAINT "connections_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."connections"
    ADD CONSTRAINT "connections_requester_id_fkey" FOREIGN KEY ("requester_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_connection_id_fkey" FOREIGN KEY ("connection_id") REFERENCES "public"."connections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_ratee_id_fkey" FOREIGN KEY ("ratee_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_rater_id_fkey" FOREIGN KEY ("rater_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_cache"
    ADD CONSTRAINT "match_cache_candidate_id_fkey" FOREIGN KEY ("candidate_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."match_cache"
    ADD CONSTRAINT "match_cache_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_connection_id_fkey" FOREIGN KEY ("connection_id") REFERENCES "public"."connections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."note_moderation_queue"
    ADD CONSTRAINT "note_moderation_queue_skill_id_fkey" FOREIGN KEY ("skill_id") REFERENCES "public"."skill_nodes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."note_moderation_queue"
    ADD CONSTRAINT "note_moderation_queue_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pipeline_config"
    ADD CONSTRAINT "pipeline_config_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profile_embeddings"
    ADD CONSTRAINT "profile_embeddings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_reported_id_fkey" FOREIGN KEY ("reported_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skill_moderation_log"
    ADD CONSTRAINT "skill_moderation_log_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."skill_nodes"
    ADD CONSTRAINT "skill_nodes_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."skill_nodes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skill_nodes"
    ADD CONSTRAINT "skill_nodes_submitted_by_fkey" FOREIGN KEY ("submitted_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."skill_showcases"
    ADD CONSTRAINT "skill_showcases_node_id_fkey" FOREIGN KEY ("skill_id") REFERENCES "public"."skill_nodes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."skill_showcases"
    ADD CONSTRAINT "skill_showcases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_skill_notes"
    ADD CONSTRAINT "user_skill_notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_skills"
    ADD CONSTRAINT "user_skills_skill_id_fkey" FOREIGN KEY ("skill_id") REFERENCES "public"."skill_nodes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_skills"
    ADD CONSTRAINT "user_skills_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Authenticated can read profiles" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated can read skill taxonomy" ON "public"."skill_nodes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can read own note queue" ON "public"."note_moderation_queue" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can read own private skill notes" ON "public"."user_skill_notes" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can read own skills" ON "public"."user_skills" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update their profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



ALTER TABLE "public"."blocks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "blocks_read" ON "public"."blocks" FOR SELECT TO "authenticated" USING (("blocker_id" = "auth"."uid"()));



CREATE POLICY "blocks_write" ON "public"."blocks" TO "authenticated" USING (("blocker_id" = "auth"."uid"())) WITH CHECK (("blocker_id" = "auth"."uid"()));



CREATE POLICY "cache_owner_read" ON "public"."match_cache" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "conn_read" ON "public"."connections" FOR SELECT TO "authenticated" USING ((("requester_id" = "auth"."uid"()) OR ("recipient_id" = "auth"."uid"())));



ALTER TABLE "public"."connections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fb_read" ON "public"."feedback" FOR SELECT TO "authenticated" USING ((("rater_id" = "auth"."uid"()) OR ("ratee_id" = "auth"."uid"())));



ALTER TABLE "public"."feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."integration_secrets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."match_cache" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "modlog_admin_read" ON "public"."skill_moderation_log" FOR SELECT TO "authenticated" USING ("public"."is_admin"());



CREATE POLICY "msg_read" ON "public"."messages" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."connections" "c"
  WHERE (("c"."id" = "messages"."connection_id") AND ("c"."status" = 'accepted'::"public"."conn_status") AND (("c"."requester_id" = "auth"."uid"()) OR ("c"."recipient_id" = "auth"."uid"()))))));



ALTER TABLE "public"."note_moderation_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notif_read" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notif_update" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pipeline_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profile_embeddings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rate_limits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "reports_insert" ON "public"."reports" FOR INSERT TO "authenticated" WITH CHECK (("reporter_id" = "auth"."uid"()));



CREATE POLICY "reports_read" ON "public"."reports" FOR SELECT TO "authenticated" USING ((("reporter_id" = "auth"."uid"()) OR "public"."is_admin"()));



CREATE POLICY "showcase_read" ON "public"."skill_showcases" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "showcase_write" ON "public"."skill_showcases" TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."skill_moderation_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."skill_nodes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."skill_showcases" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_skill_notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_skills" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."block_user"("p_target" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."block_user"("p_target" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."block_user"("p_target" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."blocked_between"("a" "uuid", "b" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."blocked_between"("a" "uuid", "b" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."browse_random_users"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."browse_random_users"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."browse_random_users"("p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."browse_skill_users"("p_node" "text", "p_kind" "public"."skill_kind", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."browse_skill_users"("p_node" "text", "p_kind" "public"."skill_kind", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."browse_skill_users"("p_node" "text", "p_kind" "public"."skill_kind", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."build_passages_bulk"("p_users" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."build_passages_bulk"("p_users" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."build_profile_passages"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."build_profile_passages"("p_user" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."bump_config_revision"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."bump_config_revision"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."cache_is_fresh"("p_user" "uuid", "p_role" "public"."embed_role", "p_revision" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cache_is_fresh"("p_user" "uuid", "p_role" "public"."embed_role", "p_revision" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_feedback_gate"("p_connection" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_feedback_gate"("p_connection" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."check_feedback_gate"("p_connection" "uuid") TO "authenticated";



GRANT ALL ON TABLE "public"."note_moderation_queue" TO "service_role";



REVOKE ALL ON FUNCTION "public"."claim_note_jobs"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_note_jobs"("p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."consume_rate_limit"("p_subject" "uuid", "p_action" "text", "p_limit" integer, "p_window_seconds" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."consume_rate_limit"("p_subject" "uuid", "p_action" "text", "p_limit" integer, "p_window_seconds" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."count_unread_notifications"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."count_unread_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."count_unread_notifications"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."email_exists"("p_email" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."email_exists"("p_email" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."enforce_leaf_only"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enforce_leaf_only"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."enforce_skill_caps"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enforce_skill_caps"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."feedback_gate_open"("p_connection" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."feedback_gate_open"("p_connection" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_block_list"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_block_list"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_block_list"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_conversation"("p_connection" "uuid", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_conversation"("p_connection" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_conversation"("p_connection" "uuid", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_conversations"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_conversations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_conversations"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_incoming_requests"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_incoming_requests"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_incoming_requests"("p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_public_profile"("p_user" "uuid", OUT "p_name" "text", OUT "p_role" "text", OUT "p_bio" "text", OUT "p_avatar" "text", OUT "p_languages" "text", OUT "p_styles" "text", OUT "p_availability" "jsonb", OUT "p_teaching" "jsonb", OUT "p_learning" "jsonb", OUT "p_showcases" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user" "uuid", OUT "p_name" "text", OUT "p_role" "text", OUT "p_bio" "text", OUT "p_avatar" "text", OUT "p_languages" "text", OUT "p_styles" "text", OUT "p_availability" "jsonb", OUT "p_teaching" "jsonb", OUT "p_learning" "jsonb", OUT "p_showcases" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user" "uuid", OUT "p_name" "text", OUT "p_role" "text", OUT "p_bio" "text", OUT "p_avatar" "text", OUT "p_languages" "text", OUT "p_styles" "text", OUT "p_availability" "jsonb", OUT "p_teaching" "jsonb", OUT "p_learning" "jsonb", OUT "p_showcases" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_public_profile"("p_user" "uuid", OUT "p_name" "text", OUT "p_role" "text", OUT "p_bio" "text", OUT "p_avatar" "text", OUT "p_languages" "text", OUT "p_styles" "text", OUT "p_availability" "jsonb", OUT "p_teaching" "jsonb", OUT "p_learning" "jsonb", OUT "p_showcases" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_notifications"("p_unread_only" boolean, "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_notifications"("p_unread_only" boolean, "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_notifications"("p_unread_only" boolean, "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_messages_read"("p_connection" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_messages_read"("p_connection" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_messages_read"("p_connection" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_notifications_read"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_notifications_read"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_notifications_read"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."match_candidates"("p_user" "uuid", "p_target" "public"."embed_role", "p_limit" integer, "p_w_skills" real, "p_w_context" real) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."match_candidates"("p_user" "uuid", "p_target" "public"."embed_role", "p_limit" integer, "p_w_skills" real, "p_w_context" real) TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_feedback_status"("p_connection" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_feedback_status"("p_connection" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."my_feedback_status"("p_connection" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."node_label"("raw" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."node_label"("raw" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."notify"("p_user" "uuid", "p_kind" "text", "p_payload" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."notify"("p_user" "uuid", "p_kind" "text", "p_payload" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."profile_match_view"("p_users" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."profile_match_view"("p_users" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."profiles_search_update"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."profiles_search_update"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."rebuild_skill_array"("p_user" "uuid", "p_kind" "public"."skill_kind", "p_existing" "text"[], "p_exclude" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rebuild_skill_array"("p_user" "uuid", "p_kind" "public"."skill_kind", "p_existing" "text"[], "p_exclude" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_user"("p_target" "uuid", "p_reason" "text", "p_details" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_user"("p_target" "uuid", "p_reason" "text", "p_details" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_user"("p_target" "uuid", "p_reason" "text", "p_details" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."resolve_skill_node"("p_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."resolve_skill_node"("p_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."respond_connection_request"("p_connection" "uuid", "p_accept" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."respond_connection_request"("p_connection" "uuid", "p_accept" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."respond_connection_request"("p_connection" "uuid", "p_accept" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_user_skills"("p_learning" "jsonb", "p_teaching" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_user_skills"("p_learning" "jsonb", "p_teaching" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_user_skills"("p_learning" "jsonb", "p_teaching" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."search_profiles"("p_query" "text", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_profiles"("p_query" "text", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."send_connection_request"("p_recipient" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."send_connection_request"("p_recipient" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_connection_request"("p_recipient" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."send_message"("p_connection" "uuid", "p_body" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."send_message"("p_connection" "uuid", "p_body" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_message"("p_connection" "uuid", "p_body" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."skill_node_path"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."skill_node_path"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."skill_slug"("raw" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."skill_slug"("raw" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."submit_feedback"("p_connection" "uuid", "p_clarity" smallint, "p_reliability" smallint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."submit_feedback"("p_connection" "uuid", "p_clarity" smallint, "p_reliability" smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_feedback"("p_connection" "uuid", "p_clarity" smallint, "p_reliability" smallint) TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_profile_email"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_profile_skill_arrays"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_profile_skill_arrays"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."taxonomy_visible"("p_root_path" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."taxonomy_visible"("p_root_path" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."taxonomy_visible"("p_root_path" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."unblock_user"("p_target" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."unblock_user"("p_target" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unblock_user"("p_target" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."unmatch_connection"("p_connection" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."unmatch_connection"("p_connection" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unmatch_connection"("p_connection" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_node_usage"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_node_usage"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_skill_usage"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_skill_usage"() TO "service_role";



GRANT ALL ON TABLE "public"."blocks" TO "service_role";



GRANT ALL ON TABLE "public"."connections" TO "service_role";
GRANT SELECT ON TABLE "public"."connections" TO "authenticated";



GRANT ALL ON TABLE "public"."feedback" TO "service_role";



GRANT ALL ON TABLE "public"."integration_secrets" TO "service_role";



GRANT ALL ON TABLE "public"."match_cache" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "service_role";
GRANT SELECT ON TABLE "public"."messages" TO "authenticated";



GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."pipeline_config" TO "service_role";



GRANT ALL ON TABLE "public"."profile_embeddings" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("id") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("first_name"),UPDATE("first_name") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("last_name"),UPDATE("last_name") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("created_at") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("role"),UPDATE("role") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("learning_skills") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("teaching_skills") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("learning_styles"),UPDATE("learning_styles") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("languages"),UPDATE("languages") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("availability"),UPDATE("availability") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("is_profile_completed"),UPDATE("is_profile_completed") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("updated_at"),UPDATE("updated_at") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("has_completed_onboarding"),UPDATE("has_completed_onboarding") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("bio"),UPDATE("bio") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("avatar_url"),UPDATE("avatar_url") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("photos"),UPDATE("photos") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("teaching_skill_images"),UPDATE("teaching_skill_images") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("skill_categories"),UPDATE("skill_categories") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("display_name"),UPDATE("display_name") ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("timezone"),UPDATE("timezone") ON TABLE "public"."profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."rate_limits" TO "service_role";



GRANT ALL ON TABLE "public"."reports" TO "service_role";



GRANT ALL ON TABLE "public"."skill_moderation_log" TO "service_role";



GRANT SELECT ON TABLE "public"."skill_nodes" TO "authenticated";
GRANT ALL ON TABLE "public"."skill_nodes" TO "service_role";



GRANT ALL ON TABLE "public"."skill_showcases" TO "service_role";



GRANT SELECT ON TABLE "public"."user_skill_notes" TO "authenticated";
GRANT ALL ON TABLE "public"."user_skill_notes" TO "service_role";



GRANT SELECT ON TABLE "public"."user_skills" TO "authenticated";
GRANT ALL ON TABLE "public"."user_skills" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";








-- Stock Supabase grants default privileges at CREATE time. The live project
-- revoked anon access down to the public-profile RPC (B1/B5/B19), so repeat
-- that explicitly after the baseline objects/grants are created.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;
grant execute on function public.get_public_profile(uuid) to anon;
-- Match the live authenticated grants after stock default privileges are
-- applied. Column-scoped profiles grants keep email/is_admin/search protected.
revoke all on all tables in schema public from authenticated;
revoke all on all sequences in schema public from authenticated;
revoke all on all functions in schema public from authenticated;

grant select on table
  public.connections,
  public.messages,
  public.skill_nodes,
  public.user_skill_notes,
  public.user_skills
to authenticated;

grant select (
  availability, avatar_url, bio, created_at, display_name, first_name,
  has_completed_onboarding, id, is_profile_completed, languages, last_name,
  learning_skills, learning_styles, photos, role, skill_categories,
  teaching_skill_images, teaching_skills, timezone, updated_at
) on public.profiles to authenticated;

grant update (
  availability, avatar_url, bio, display_name, first_name,
  has_completed_onboarding, is_profile_completed, languages, last_name,
  learning_styles, photos, role, skill_categories, teaching_skill_images,
  timezone, updated_at
) on public.profiles to authenticated;

grant execute on function
  public.block_user(uuid),
  public.browse_random_users(integer),
  public.browse_skill_users(text, public.skill_kind, integer),
  public.check_feedback_gate(uuid),
  public.count_unread_notifications(),
  public.get_block_list(),
  public.get_conversation(uuid, integer),
  public.get_conversations(),
  public.get_incoming_requests(integer),
  public.get_public_profile(uuid),
  public.is_admin(),
  public.list_notifications(boolean, integer),
  public.mark_messages_read(uuid),
  public.mark_notifications_read(),
  public.my_feedback_status(uuid),
  public.report_user(uuid, text, text),
  public.respond_connection_request(uuid, boolean),
  public.save_user_skills(jsonb, jsonb),
  public.send_connection_request(uuid),
  public.send_message(uuid, text),
  public.submit_feedback(uuid, smallint, smallint),
  public.taxonomy_visible(text),
  public.unblock_user(uuid),
  public.unmatch_connection(uuid)
to authenticated;
-- Keep future objects created by postgres private by default too.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;