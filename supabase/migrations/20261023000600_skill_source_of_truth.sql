-- B7 + H4: make user_skills the source of truth for skills and persist notes.
--
-- The client wrote profiles.learning_skills / teaching_skills (display names)
-- and never user_skills, which the matcher and browse RPCs read. user_skills
-- also has a note column that the editor never sent. This migration:
--   1. resolves a display name to a taxonomy leaf (exact, path, token set)
--   2. adds save_user_skills(...) for transactional replacement + notes
--   3. backfills user_skills from the existing profile arrays
--   4. keeps unapproved notes out of public output and embeddings
--   5. lets users read their own skills (and the taxonomy) with RLS

-- 0. Note moderation state --------------------------------------------------
-- Only approve legacy notes on the run that creates the column. Re-running
-- the migration must not re-publish notes a user has edited since.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'user_skills'
      and column_name = 'note_approved'
  ) then
    execute 'alter table public.user_skills
      add column note_approved boolean not null default false';
    update public.user_skills
    set note_approved = true
    where note is not null and btrim(note) <> '';
  end if;
end $$;

-- 0b. Durable note moderation queue ----------------------------------------
create table if not exists public.note_moderation_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind public.skill_kind not null,
  name text not null,
  skill_id uuid references public.skill_nodes(id) on delete set null,
  note text not null,
  note_hash text not null,
  status text not null default 'pending'
    check (status in ('pending','processing','approved','rejected','unresolved','error','stale')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, kind, name)
);

create index if not exists note_queue_status_idx
  on public.note_moderation_queue (status, created_at);

-- Notes for skills that are not (yet) taxonomy nodes. Owner-visible only.
create table if not exists public.user_skill_notes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind public.skill_kind not null,
  name text not null,
  note text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, name)
);

alter table public.note_moderation_queue enable row level security;
alter table public.user_skill_notes enable row level security;

drop policy if exists "Users can read own note queue" on public.note_moderation_queue;
create policy "Users can read own note queue"
  on public.note_moderation_queue
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users can read own private skill notes" on public.user_skill_notes;
create policy "Users can read own private skill notes"
  on public.user_skill_notes
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.note_moderation_queue from anon;
revoke all on public.user_skill_notes from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.note_moderation_queue from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.user_skill_notes from authenticated;
grant select on public.note_moderation_queue to authenticated;
grant select on public.user_skill_notes to authenticated;

create or replace function public.claim_note_jobs(p_limit integer default 10)
returns setof public.note_moderation_queue
language sql
security definer
set search_path = public
as $$
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

revoke all on function public.claim_note_jobs(integer) from public;
revoke all on function public.claim_note_jobs(integer) from anon;
revoke all on function public.claim_note_jobs(integer) from authenticated;
grant execute on function public.claim_note_jobs(integer) to service_role;

-- 1. Resolver --------------------------------------------------------------
create or replace function public.resolve_skill_node(p_name text)
returns uuid
language plpgsql
stable
set search_path = public
as $$
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

revoke all on function public.resolve_skill_node(text) from public;
revoke all on function public.resolve_skill_node(text) from anon;
revoke all on function public.resolve_skill_node(text) from authenticated;

-- 1b. Mirror trigger -------------------------------------------------------
-- Rebuild only the changed kind. The old trigger rewrote both arrays, which
-- dropped unresolved custom names from the untouched kind on any one-argument
-- save or classify-skill placement.
drop function if exists public.note_is_publishable(text);
drop function if exists public.rebuild_skill_array(uuid, public.skill_kind, text[]);

create or replace function public.rebuild_skill_array(
  p_user uuid,
  p_kind public.skill_kind,
  p_existing text[],
  p_exclude uuid default null
)
returns text[]
language sql
stable
set search_path = public
as $$
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

revoke all on function public.rebuild_skill_array(uuid, public.skill_kind, text[], uuid) from public;
revoke all on function public.rebuild_skill_array(uuid, public.skill_kind, text[], uuid) from anon;
revoke all on function public.rebuild_skill_array(uuid, public.skill_kind, text[], uuid) from authenticated;

create or replace function public.sync_profile_skill_arrays()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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

create index if not exists user_skills_kind_idx
  on public.user_skills (kind);

-- 2. Save RPC --------------------------------------------------------------
-- p_learning / p_teaching are JSON arrays of {"name": "...", "note": "..."}.
-- A missing "note" key means "do not change the stored note".
create or replace function public.save_user_skills(
  p_learning jsonb default null,
  p_teaching jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

revoke all on function public.save_user_skills(jsonb, jsonb) from public;
revoke all on function public.save_user_skills(jsonb, jsonb) from anon;
grant execute on function public.save_user_skills(jsonb, jsonb) to authenticated;

-- 2b. Candidate retrieval fallback -----------------------------------------
-- Backfilled users may not have embeddings yet. Include everyone who has a
-- target-role skill in user_skills; get-matches reranks them from live text,
-- so a missing/stale vector no longer makes a user invisible.
create or replace function public.match_candidates(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real
)
returns table(candidate_id uuid, bi_score real)
language sql
stable
security definer
set search_path to 'public'
as $function$
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
$function$;

revoke all on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) from public;
revoke all on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) from anon;
revoke all on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) from authenticated;
grant execute on function public.match_candidates(
  uuid, public.embed_role, integer, real, real
) to service_role;

-- 3. Note gating in public output / embeddings -----------------------------
create or replace function public.build_profile_passages(p_user uuid)
returns table(role embed_role, field_group embed_field_group, source_text text, source_hash text)
language sql
stable
as $function$
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
$function$;

create or replace function public.get_public_profile(
  p_user uuid,
  out p_name text,
  out p_role text,
  out p_bio text,
  out p_avatar text,
  out p_languages text,
  out p_styles text,
  out p_availability jsonb,
  out p_teaching jsonb,
  out p_learning jsonb,
  out p_showcases jsonb
)
returns record
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
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
end $function$;

create or replace function public.browse_skill_users(
  p_node text,
  p_kind public.skill_kind default 'teach',
  p_limit integer default 50
)
returns table(user_id uuid, name text, role text, avatar_url text, note text)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $function$
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
$function$;

revoke all on function public.browse_skill_users(text, public.skill_kind, integer) from public;
revoke all on function public.browse_skill_users(text, public.skill_kind, integer) from anon;
grant execute on function public.browse_skill_users(text, public.skill_kind, integer) to authenticated;

-- 4. Backfill existing profile arrays --------------------------------------
-- Capture every original array name before the row trigger rewrites arrays,
-- so unresolved and over-cap names can be restored afterwards.
drop table if exists _b7_original;
create temp table _b7_original (
  user_id uuid, kind public.skill_kind, name text
);

insert into _b7_original (user_id, kind, name)
select p.id, k.kind, k.name
from public.profiles p
cross join lateral (
  select 'learn'::public.skill_kind as kind, unnest(p.learning_skills) as name
  union all
  select 'teach'::public.skill_kind, unnest(p.teaching_skills)
) k
where btrim(coalesce(k.name, '')) <> '';

do $$
declare
  r record;
  v_node uuid;
  v_have integer;
begin
  for r in
    select p.id, k.kind, k.name
    from public.profiles p
    cross join lateral (
      select 'learn'::public.skill_kind as kind, unnest(p.learning_skills) as name
      union all
      select 'teach'::public.skill_kind, unnest(p.teaching_skills)
    ) k
    where btrim(coalesce(k.name, '')) <> ''
  loop
    v_node := public.resolve_skill_node(r.name);
    if v_node is null then
      continue;
    end if;

    select count(*) into v_have
    from public.user_skills
    where user_id = r.id and kind = r.kind;
    if v_have >= 3 then
      continue;
    end if;

    if exists (
      select 1 from public.user_skills
      where user_id = r.id and skill_id = v_node and kind = r.kind
    ) then
      continue;
    end if;

    insert into public.user_skills (user_id, skill_id, kind)
    values (r.id, v_node, r.kind);
  end loop;
end $$;

-- Restore canonical names plus original names that have no row (unresolved
-- customs and legacy over-cap entries). Aliases that resolve to a kept row
-- are represented by the canonical name only.
update public.profiles p
set learning_skills = (
      select coalesce(array_agg(distinct x order by x), '{}'::text[])
      from (
        select n.name as x
        from public.user_skills us
        join public.skill_nodes n on n.id = us.skill_id
        where us.user_id = p.id and us.kind = 'learn'
        union
        select o.name
        from _b7_original o
        where o.user_id = p.id and o.kind = 'learn'
          and (
            public.resolve_skill_node(o.name) is null
            or public.resolve_skill_node(o.name) not in (
              select us.skill_id from public.user_skills us
              where us.user_id = p.id and us.kind = 'learn'
            )
          )
      ) q
    ),
    teaching_skills = (
      select coalesce(array_agg(distinct x order by x), '{}'::text[])
      from (
        select n.name as x
        from public.user_skills us
        join public.skill_nodes n on n.id = us.skill_id
        where us.user_id = p.id and us.kind = 'teach'
        union
        select o.name
        from _b7_original o
        where o.user_id = p.id and o.kind = 'teach'
          and (
            public.resolve_skill_node(o.name) is null
            or public.resolve_skill_node(o.name) not in (
              select us.skill_id from public.user_skills us
              where us.user_id = p.id and us.kind = 'teach'
            )
          )
      ) q
    );

drop table if exists _b7_original;

-- 5. RLS / grants ----------------------------------------------------------
drop policy if exists "Users can read own skills" on public.user_skills;
create policy "Users can read own skills"
  on public.user_skills
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Authenticated can read skill taxonomy" on public.skill_nodes;
create policy "Authenticated can read skill taxonomy"
  on public.skill_nodes
  for select
  to authenticated
  using (true);

revoke all on public.user_skills from anon;
revoke all on public.skill_nodes from anon;
revoke all on public.integration_secrets from anon;
revoke all on public.integration_secrets from authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.user_skills from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.skill_nodes from authenticated;

-- The RPC is now the only writer of the skill mirror. Direct PATCHes of these
-- columns would desync profiles from user_skills.
revoke update (learning_skills, teaching_skills)
  on public.profiles from authenticated;

grant select on public.user_skills to authenticated;
grant select on public.skill_nodes to authenticated;

-- Backfilled users need fresh embeddings before decks can include them. The
-- caller self-heals on their next deck load; invalidate cached rankings now.
update public.pipeline_config
set updated_at = now()
where key = 'candidate_pool_k';
