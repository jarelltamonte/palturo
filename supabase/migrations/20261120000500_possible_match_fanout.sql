-- Possible match notifications, phase 2: reverse lookup and fan-out worker.
--
-- A candidate edit becomes a job. Each cron tick reaps stale claims, claims due
-- jobs with SKIP LOCKED, asks "who could plausibly want this profile?", then
-- writes one audit event per pair. Only `live` mode writes an actual
-- notification. `shadow` records the same decision without touching Activity.

create or replace function public.possible_match_setting(
  p_key text,
  p_default jsonb
)
returns jsonb
language sql
stable
security definer
set search_path = 'public'
as $$
  select coalesce(
    (select value from public.pipeline_config where key = p_key),
    p_default
  );
$$;

revoke all on function public.possible_match_setting(text, jsonb)
  from public, anon, authenticated;

-- Public rollout state for the app. This is the only possible-match RPC an
-- authenticated client may call; it exposes no candidate data.
create or replace function public.possible_match_status()
returns jsonb
language sql
stable
security definer
set search_path = 'public'
as $$
  select jsonb_build_object(
    'enabled', coalesce((
      select (value #>> '{}')::boolean from public.pipeline_config
      where key = 'possible_match_enabled'
    ), false),
    'mode', coalesce((
      select value #>> '{}' from public.pipeline_config
      where key = 'possible_match_mode'
    ), 'off')
  );
$$;

revoke all on function public.possible_match_status()
  from public, anon;
grant execute on function public.possible_match_status() to authenticated;

-- Returns stored vectors whose source hash still matches the passage SQL for
-- the requested users. This is the freshness contract: a vector from an old
-- skill list, old language, or a retired embedding model is not current.
create or replace function public.possible_match_current_vectors(p_users uuid[])
returns table (
  user_id uuid,
  role public.embed_role,
  field_group public.embed_field_group,
  input_type text,
  embedding extensions.vector(1024)
)
language sql
stable
security definer
set search_path = 'public, extensions'
as $$
  with passages as (
    select u.uid as user_id, b.role, b.field_group, b.source_hash
    from unnest(coalesce(p_users, '{}'::uuid[])) as u(uid)
    cross join lateral public.build_profile_passages(u.uid) b
  ),
  model as (
    select coalesce(
      (select value #>> '{}' from public.pipeline_config
       where key = 'embedding_model'),
      'nvidia/nemotron-3.5-embed-1b'
    ) as name
  )
  select e.user_id, e.role, e.field_group, e.input_type, e.embedding
  from passages p
  join public.profile_embeddings e
    on e.user_id = p.user_id
   and e.role = p.role
   and e.field_group = p.field_group
   and e.source_hash = p.source_hash
   and e.model_name = (select name from model)
  where e.input_type in ('passage','query');
$$;

revoke all on function public.possible_match_current_vectors(uuid[])
  from public, anon, authenticated;

-- A direction is ready when the candidate has current skills and context
-- passages for that side, and the mentor side also has discovery media.
create or replace function public.possible_match_ready_roles(p_candidate uuid)
returns table (as_role public.embed_role)
language sql
stable
security definer
set search_path = 'public, extensions'
as $$
  with candidate as (
    select p.id, p.role
    from public.profiles p
    where p.id = p_candidate
      and coalesce(p.has_completed_onboarding, false)
      and p.moderation_status = 'active'
  ),
  vectors as (
    select v.role, v.field_group
    from public.possible_match_current_vectors(array[p_candidate]) v
    where v.input_type = 'passage'
  )
  select r.as_role
  from candidate c
  cross join (values
    ('mentor'::public.embed_role),
    ('learner'::public.embed_role)
  ) as r(as_role)
  where (
      (r.as_role = 'mentor' and c.role in ('mentor','both'))
      or (r.as_role = 'learner' and c.role in ('learner','both'))
    )
    and exists (
      select 1 from vectors v
      where v.role = r.as_role and v.field_group = 'skills'
    )
    and exists (
      select 1 from vectors v
      where v.role = r.as_role and v.field_group = 'context'
    )
    and (
      r.as_role <> 'mentor'
      or public.has_discovery_media(p_candidate)
    );
$$;

revoke all on function public.possible_match_ready_roles(uuid)
  from public, anon, authenticated;

-- Reverse retrieval. Direction A treats the candidate as the mentor and looks
-- for learners; direction B treats the candidate as the learner and looks for
-- mentors. Scores use the same skill/context weights as get-matches. Exact
-- skill overlap is a lower-confidence fallback for viewers with no vectors.
create or replace function public.possible_match_recipients(
  p_candidate uuid,
  p_limit integer default 250
)
returns table (
  recipient_id uuid,
  as_role public.embed_role,
  score real,
  skill_name text,
  skill_path text,
  source text
)
language sql
stable
security definer
set search_path = 'public, extensions'
as $$
  with cfg as (
    select
      coalesce((
        select (value ->> 'skills')::real from public.pipeline_config
        where key = 'embedding_weights'
      ), 0.7) as w_skills,
      coalesce((
        select (value ->> 'context')::real from public.pipeline_config
        where key = 'embedding_weights'
      ), 0.3) as w_context,
      coalesce((
        select (value #>> '{}')::real from public.pipeline_config
        where key = 'possible_match_min_score'
      ), 0.12) as min_score,
      coalesce((
        select (value #>> '{}')::real from public.pipeline_config
        where key = 'possible_match_fallback_score'
      ), 0.12) as fallback_score,
      coalesce((
        select (value #>> '{}')::boolean from public.pipeline_config
        where key = 'possible_match_skill_fallback'
      ), true) as fallback_enabled,
      coalesce((
        select (value #>> '{}')::int from public.pipeline_config
        where key = 'possible_match_recall_k'
      ), 200) as recall_k,
      coalesce((
        select (value #>> '{}')::int from public.pipeline_config
        where key = 'possible_match_inactive_days'
      ), 0) as inactive_days
  ),
  candidate as (
    select p.id, p.role
    from public.profiles p
    where p.id = p_candidate
      and coalesce(p.has_completed_onboarding, false)
      and p.moderation_status = 'active'
  ),
  cand_vec as (
    select v.role, v.field_group, v.embedding
    from public.possible_match_current_vectors(array[p_candidate]) v
    where v.input_type = 'passage'
  ),
  dirs as (
    select 'mentor'::public.embed_role as as_role,
           'learner'::public.embed_role as viewer_role
    where exists (
        select 1 from candidate c where c.role in ('mentor','both')
      )
      and exists (
        select 1 from cand_vec v
        where v.role = 'mentor' and v.field_group = 'skills'
      )
      and exists (
        select 1 from cand_vec v
        where v.role = 'mentor' and v.field_group = 'context'
      )
      and public.has_discovery_media(p_candidate)
    union all
    select 'learner'::public.embed_role,
           'mentor'::public.embed_role
    where exists (
        select 1 from candidate c where c.role in ('learner','both')
      )
      and exists (
        select 1 from cand_vec v
        where v.role = 'learner' and v.field_group = 'skills'
      )
      and exists (
        select 1 from cand_vec v
        where v.role = 'learner' and v.field_group = 'context'
      )
  ),
  skill_scores as (
    select d.as_role,
           s.user_id as recipient_id,
           s.sim as skills_sim,
           coalesce((
             select 1 - extensions.cosine_distance(cx.embedding, e2.embedding)
             from public.profile_embeddings e2
             join cand_vec cx
               on cx.role = d.as_role and cx.field_group = 'context'
             where e2.user_id = s.user_id
               and e2.role = d.viewer_role
               and e2.input_type = 'query'
               and e2.field_group = 'context'
             limit 1
           ), 0)::real as context_sim
    from dirs d
    cross join lateral (
      select e.user_id,
             (1 - extensions.cosine_distance(cs.embedding, e.embedding))::real as sim
      from public.profile_embeddings e
      join cand_vec cs
        on cs.role = d.as_role and cs.field_group = 'skills'
      where e.role = d.viewer_role
        and e.input_type = 'query'
        and e.field_group = 'skills'
        and e.user_id <> p_candidate
      order by e.embedding operator(extensions.<=>) cs.embedding
      limit (select recall_k from cfg)
    ) s
  ),
  scored as (
    select s.as_role,
           s.recipient_id,
           (c.w_skills * s.skills_sim + c.w_context * s.context_sim)::real as score,
           'embedding'::text as source,
           null::text as skill_name,
           null::text as skill_path
    from skill_scores s
    cross join cfg c
  ),
  fallback as (
    select d.as_role,
           v.id as recipient_id,
           c.fallback_score as score,
           'skill_fallback'::text as source,
           sn.name as skill_name,
           sn.path::text as skill_path
    from dirs d
    cross join cfg c
    join public.user_skills cand_skill
      on cand_skill.user_id = p_candidate
     and cand_skill.kind = (case
           when d.as_role = 'mentor' then 'teach' else 'learn'
         end)::public.skill_kind
    join public.skill_nodes sn
      on sn.id = cand_skill.skill_id
     and sn.kind = 'skill'
     and sn.status = 'approved'
    join public.user_skills viewer_skill
      on viewer_skill.skill_id = cand_skill.skill_id
     and viewer_skill.kind = (case
           when d.as_role = 'mentor' then 'learn' else 'teach'
         end)::public.skill_kind
    join public.profiles v on v.id = viewer_skill.user_id
    where c.fallback_enabled
      and v.id <> p_candidate
  ),
  unioned as (
    select * from scored
    union all
    select as_role, recipient_id, score, source, skill_name, skill_path
    from fallback
  ),
  enriched as (
    select u.*,
           coalesce(
             u.skill_name,
             (
               select sn.name
               from public.user_skills viewer_skill
               join public.skill_nodes sn
                 on sn.id = viewer_skill.skill_id
                and sn.kind = 'skill'
                and sn.status = 'approved'
               join public.user_skills cand_skill
                 on cand_skill.skill_id = viewer_skill.skill_id
                and cand_skill.user_id = p_candidate
                and cand_skill.kind = (case
                      when u.as_role = 'mentor' then 'teach' else 'learn'
                    end)::public.skill_kind
               where viewer_skill.user_id = u.recipient_id
                 and viewer_skill.kind = (case
                       when u.as_role = 'mentor' then 'learn' else 'teach'
                     end)::public.skill_kind
               order by sn.depth, sn.name
               limit 1
             ),
             (
               select sn.name
               from public.user_skills us
               join public.skill_nodes sn
                 on sn.id = us.skill_id
                and sn.kind = 'skill'
                and sn.status = 'approved'
               where us.user_id = p_candidate
                 and us.kind = (case
                       when u.as_role = 'mentor' then 'teach' else 'learn'
                     end)::public.skill_kind
               order by sn.depth, sn.name
               limit 1
             )
           ) as resolved_skill_name,
           coalesce(
             u.skill_path,
             (
               select sn.path::text
               from public.user_skills viewer_skill
               join public.skill_nodes sn
                 on sn.id = viewer_skill.skill_id
                and sn.kind = 'skill'
                and sn.status = 'approved'
               join public.user_skills cand_skill
                 on cand_skill.skill_id = viewer_skill.skill_id
                and cand_skill.user_id = p_candidate
                and cand_skill.kind = (case
                      when u.as_role = 'mentor' then 'teach' else 'learn'
                    end)::public.skill_kind
               where viewer_skill.user_id = u.recipient_id
                 and viewer_skill.kind = (case
                       when u.as_role = 'mentor' then 'learn' else 'teach'
                     end)::public.skill_kind
               order by sn.depth, sn.name
               limit 1
             ),
             (
               select sn.path::text
               from public.user_skills us
               join public.skill_nodes sn
                 on sn.id = us.skill_id
                and sn.kind = 'skill'
                and sn.status = 'approved'
               where us.user_id = p_candidate
                 and us.kind = (case
                       when u.as_role = 'mentor' then 'teach' else 'learn'
                     end)::public.skill_kind
               order by sn.depth, sn.name
               limit 1
             )
           ) as resolved_skill_path
    from unioned u
  ),
  eligible as (
    select e.*
    from enriched e
    join public.profiles r on r.id = e.recipient_id
    cross join cfg c
    where coalesce(r.has_completed_onboarding, false)
      and r.moderation_status = 'active'
      and (
        (e.as_role = 'mentor' and r.role in ('learner','both'))
        or (e.as_role = 'learner' and r.role in ('mentor','both'))
      )
      and e.score >= c.min_score
      and (
        c.inactive_days <= 0
        or r.last_seen_at is null
        or r.last_seen_at >= now() - make_interval(days => c.inactive_days)
      )
      and not exists (
        select 1 from public.blocks b
        where (b.blocker_id = p_candidate and b.blocked_id = e.recipient_id)
           or (b.blocker_id = e.recipient_id and b.blocked_id = p_candidate)
      )
      and not exists (
        select 1 from public.connections conn
        where (conn.requester_id = p_candidate and conn.recipient_id = e.recipient_id)
           or (conn.requester_id = e.recipient_id and conn.recipient_id = p_candidate)
      )
      and not exists (
        select 1 from public.reports rep
        where (rep.reporter_id = p_candidate and rep.reported_id = e.recipient_id)
           or (rep.reporter_id = e.recipient_id and rep.reported_id = p_candidate)
      )
      and not exists (
        select 1 from public.match_cache mc
        where mc.user_id = e.recipient_id
          and mc.as_role = e.as_role
          and mc.candidate_id = p_candidate
      )
  ),
  best as (
    select distinct on (recipient_id)
      recipient_id, as_role, score,
      resolved_skill_name as skill_name,
      resolved_skill_path as skill_path,
      source
    from eligible
    order by recipient_id, score desc, as_role
  )
  select recipient_id, as_role, score, skill_name, skill_path, source
  from best
  order by score desc
  limit greatest(1, least(coalesce(p_limit, 250), 1000));
$$;

revoke all on function public.possible_match_recipients(uuid, integer)
  from public, anon, authenticated;

-- One pair, one lock, one event. The caller gets a short status string so the
-- worker can count what happened without another round trip.
create or replace function public.emit_possible_match_notification(
  p_recipient uuid,
  p_candidate uuid,
  p_as_role public.embed_role,
  p_score real,
  p_skill_name text,
  p_skill_path text,
  p_reason text
)
returns text
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_enabled boolean;
  v_mode text;
  v_score real;
  v_min_score real;
  v_cooldown interval;
  v_day_cap integer;
  v_week_cap integer;
  v_day_count integer;
  v_week_count integer;
  v_last timestamptz;
  v_status text;
  v_reason text;
  v_notification_id uuid;
begin
  if p_recipient is null or p_candidate is null or p_recipient = p_candidate then
    return 'skipped:self';
  end if;

  v_enabled := coalesce((
    select (value #>> '{}')::boolean from public.pipeline_config
    where key = 'possible_match_enabled'
  ), true);
  v_mode := coalesce((
    select value #>> '{}' from public.pipeline_config
    where key = 'possible_match_mode'
  ), 'off');
  if not v_enabled or v_mode not in ('shadow','live') then
    return 'skipped:disabled';
  end if;

  v_score := case
    when p_score is null or p_score <> p_score then 0
    else greatest(0, least(1, p_score))
  end;
  v_min_score := coalesce((
    select (value #>> '{}')::real from public.pipeline_config
    where key = 'possible_match_min_score'
  ), 0.12);
  if v_score < v_min_score then
    return 'suppressed:low_score';
  end if;

  -- Caps are per recipient. Serializing here means two candidate jobs that
  -- finish in the same minute cannot both spend the last daily slot.
  perform pg_advisory_xact_lock(
    hashtextextended('possible_match:' || p_recipient::text, 0)
  );

  if not exists (
    select 1 from public.profiles p
    where p.id = p_candidate
      and coalesce(p.has_completed_onboarding, false)
      and p.moderation_status = 'active'
      and (
        (p_as_role = 'mentor'
          and p.role in ('mentor','both')
          and public.has_discovery_media(p.id))
        or (p_as_role = 'learner' and p.role in ('learner','both'))
      )
  ) then
    v_status := 'suppressed';
    v_reason := 'candidate_ineligible';
  elsif not exists (
    select 1 from public.profiles r
    where r.id = p_recipient
      and coalesce(r.has_completed_onboarding, false)
      and r.moderation_status = 'active'
  ) then
    v_status := 'suppressed';
    v_reason := 'recipient_ineligible';
  elsif exists (
    select 1 from public.blocks b
    where (b.blocker_id = p_candidate and b.blocked_id = p_recipient)
       or (b.blocker_id = p_recipient and b.blocked_id = p_candidate)
  ) then
    v_status := 'suppressed';
    v_reason := 'blocked';
  elsif exists (
    select 1 from public.connections conn
    where (conn.requester_id = p_candidate and conn.recipient_id = p_recipient)
       or (conn.requester_id = p_recipient and conn.recipient_id = p_candidate)
  ) then
    v_status := 'suppressed';
    v_reason := 'connected';
  elsif exists (
    select 1 from public.reports rep
    where (rep.reporter_id = p_candidate and rep.reported_id = p_recipient)
       or (rep.reporter_id = p_recipient and rep.reported_id = p_candidate)
  ) then
    v_status := 'suppressed';
    v_reason := 'reported';
  elsif exists (
    select 1 from public.match_cache mc
    where mc.user_id = p_recipient
      and mc.as_role = p_as_role
      and mc.candidate_id = p_candidate
  ) then
    v_status := 'suppressed';
    v_reason := 'in_cache';
  else
    v_cooldown := make_interval(days => greatest(0, coalesce((
      select (value #>> '{}')::int from public.pipeline_config
      where key = 'possible_match_cooldown_days'
    ), 60)));

    select last_notified_at into v_last
    from public.possible_match_events
    where recipient_id = p_recipient and candidate_id = p_candidate;

    if v_last is not null and v_last > now() - v_cooldown then
      v_status := 'suppressed';
      v_reason := 'cooldown';
    else
      v_day_cap := greatest(1, coalesce((
        select (value #>> '{}')::int from public.pipeline_config
        where key = 'possible_match_daily_cap'
      ), 3));
      v_week_cap := greatest(1, coalesce((
        select (value #>> '{}')::int from public.pipeline_config
        where key = 'possible_match_weekly_cap'
      ), 10));

      select count(*)::integer into v_day_count
      from public.possible_match_events
      where recipient_id = p_recipient
        and last_notified_at >= now() - interval '24 hours';

      select count(*)::integer into v_week_count
      from public.possible_match_events
      where recipient_id = p_recipient
        and last_notified_at >= now() - interval '7 days';

      if v_day_count >= v_day_cap then
        v_status := 'suppressed';
        v_reason := 'daily_cap';
      elsif v_week_count >= v_week_cap then
        v_status := 'suppressed';
        v_reason := 'weekly_cap';
      elsif v_mode = 'live' then
        insert into public.notifications (user_id, kind, payload)
        values (
          p_recipient,
          'possible_match',
          jsonb_strip_nulls(jsonb_build_object(
            'candidate_id', p_candidate,
            'as_role', p_as_role::text,
            'score', round(v_score::numeric, 4),
            'skill_name', nullif(btrim(coalesce(p_skill_name, '')), ''),
            'skill_path', nullif(btrim(coalesce(p_skill_path, '')), ''),
            'reason', coalesce(p_reason, 'profile_update')
          ))
        )
        returning id into v_notification_id;
        v_status := 'notified';
        v_reason := null;
      else
        -- Shadow rows deliberately record a would-notify timestamp so caps and
        -- cooldown are modeled against the same timetable live mode will use.
        v_status := 'shadow';
        v_reason := null;
      end if;
    end if;
  end if;

  insert into public.possible_match_events (
    recipient_id, candidate_id, as_role, score, skill_name, skill_path,
    status, suppressed_reason, last_notified_at, notification_id,
    created_at, updated_at
  ) values (
    p_recipient, p_candidate, p_as_role, v_score,
    nullif(btrim(coalesce(p_skill_name, '')), ''),
    nullif(btrim(coalesce(p_skill_path, '')), ''),
    v_status, v_reason,
    case when v_status in ('notified','shadow') then now() else null end,
    v_notification_id, now(), now()
  )
  on conflict (recipient_id, candidate_id) do update set
    as_role = excluded.as_role,
    score = greatest(public.possible_match_events.score, excluded.score),
    skill_name = coalesce(excluded.skill_name, public.possible_match_events.skill_name),
    skill_path = coalesce(excluded.skill_path, public.possible_match_events.skill_path),
    status = case
      when public.possible_match_events.status in ('notified','shadow')
       and excluded.status = 'suppressed'
       and excluded.suppressed_reason in ('cooldown','daily_cap','weekly_cap','in_cache')
        then public.possible_match_events.status
      else excluded.status
    end,
    suppressed_reason = case
      when public.possible_match_events.status in ('notified','shadow')
       and excluded.status = 'suppressed'
       and excluded.suppressed_reason in ('cooldown','daily_cap','weekly_cap','in_cache')
        then public.possible_match_events.suppressed_reason
      else excluded.suppressed_reason
    end,
    last_notified_at = coalesce(
      excluded.last_notified_at,
      public.possible_match_events.last_notified_at
    ),
    notification_id = coalesce(
      excluded.notification_id,
      public.possible_match_events.notification_id
    ),
    updated_at = now();

  return v_status || case when v_reason is null then '' else ':' || v_reason end;
end;
$$;

revoke all on function public.emit_possible_match_notification(
  uuid, uuid, public.embed_role, real, text, text, text
) from public, anon, authenticated;

create or replace function public.claim_possible_match_jobs(p_limit integer default 20)
returns setof public.possible_match_jobs
language sql
security definer
set search_path = 'public'
as $$
  with due as (
    select id
    from public.possible_match_jobs
    where status = 'pending' and run_after <= now()
    order by run_after, id
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update skip locked
  )
  update public.possible_match_jobs j
  set status = 'processing',
      attempts = j.attempts + 1,
      locked_at = now(),
      updated_at = now()
  from due
  where j.id = due.id
  returning j.*;
$$;

revoke all on function public.claim_possible_match_jobs(integer)
  from public, anon, authenticated;

create or replace function public.process_possible_match_jobs(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_enabled boolean;
  v_mode text;
  v_max_attempts integer;
  v_lock_minutes integer;
  v_retention_days integer;
  v_job record;
  v_recipient record;
  v_roles public.embed_role[];
  v_claimed integer := 0;
  v_candidates integer := 0;
  v_notified integer := 0;
  v_shadow integer := 0;
  v_suppressed integer := 0;
  v_failed integer := 0;
  v_job_notified integer;
  v_result text;
  v_last_error text;
begin
  v_enabled := coalesce((
    select (value #>> '{}')::boolean from public.pipeline_config
    where key = 'possible_match_enabled'
  ), true);
  v_mode := coalesce((
    select value #>> '{}' from public.pipeline_config
    where key = 'possible_match_mode'
  ), 'off');
  if not v_enabled or v_mode not in ('shadow','live') then
    return jsonb_build_object(
      'mode', v_mode, 'claimed', 0, 'candidates', 0,
      'notified', 0, 'shadow', 0, 'suppressed', 0, 'failed', 0
    );
  end if;

  v_max_attempts := greatest(1, coalesce((
    select (value #>> '{}')::int from public.pipeline_config
    where key = 'possible_match_max_attempts'
  ), 5));
  v_lock_minutes := greatest(1, coalesce((
    select (value #>> '{}')::int from public.pipeline_config
    where key = 'possible_match_job_lock_minutes'
  ), 5));
  v_retention_days := greatest(1, coalesce((
    select (value #>> '{}')::int from public.pipeline_config
    where key = 'possible_match_retention_days'
  ), 90));

  -- A worker that dies mid-job must not wedge a candidate forever.
  update public.possible_match_jobs j
  set status = case
        when j.attempts >= v_max_attempts then 'failed'
        else 'pending'
      end,
      run_after = case
        when j.attempts >= v_max_attempts then j.run_after
        else now() + make_interval(
          secs => least(300, 30 * (2 ^ greatest(j.attempts - 1, 0)))
        )
      end,
      locked_at = null,
      last_error = coalesce(j.last_error, 'stale_claim'),
      updated_at = now()
  where j.status = 'processing'
    and j.locked_at < now() - make_interval(mins => v_lock_minutes);

  for v_job in
    select * from public.claim_possible_match_jobs(p_limit)
  loop
    v_claimed := v_claimed + 1;
    v_candidates := v_candidates + 1;
    v_job_notified := 0;

    begin
      -- Ineligible candidates are skipped, not retried. Missing vectors are a
      -- transient condition and are retried with backoff.
      if not exists (
        select 1 from public.profiles p
        where p.id = v_job.candidate_id
          and coalesce(p.has_completed_onboarding, false)
          and p.moderation_status = 'active'
      ) then
        update public.possible_match_jobs
        set status = 'skipped',
            locked_at = null,
            last_error = 'candidate_ineligible',
            updated_at = now()
        where id = v_job.id;
        continue;
      end if;

      if not exists (
        select 1
        from public.user_skills us
        join public.skill_nodes sn
          on sn.id = us.skill_id
         and sn.kind = 'skill'
         and sn.status = 'approved'
        where us.user_id = v_job.candidate_id
          and us.kind in ('teach','learn')
      ) then
        update public.possible_match_jobs
        set status = 'skipped',
            locked_at = null,
            last_error = 'no_approved_skills',
            updated_at = now()
        where id = v_job.id;
        continue;
      end if;

      -- No mentor media and no learner side means there is no direction to
      -- notify for, even after retries.
      if not public.has_discovery_media(v_job.candidate_id)
         and not exists (
           select 1 from public.user_skills
           where user_id = v_job.candidate_id and kind = 'learn'
         ) then
        update public.possible_match_jobs
        set status = 'skipped',
            locked_at = null,
            last_error = 'mentor_without_media',
            updated_at = now()
        where id = v_job.id;
        continue;
      end if;

      select coalesce(array_agg(r.as_role), '{}'::public.embed_role[])
      into v_roles
      from public.possible_match_ready_roles(v_job.candidate_id) r;

      if coalesce(array_length(v_roles, 1), 0) = 0 then
        raise exception 'embeddings_not_fresh';
      end if;

      for v_recipient in
        select *
        from public.possible_match_recipients(
          v_job.candidate_id,
          coalesce((
            select (value #>> '{}')::int from public.pipeline_config
            where key = 'possible_match_recipients_per_job'
          ), 100)
        ) r
        where r.as_role = any (v_roles)
      loop
        v_result := public.emit_possible_match_notification(
          v_recipient.recipient_id,
          v_job.candidate_id,
          v_recipient.as_role,
          v_recipient.score,
          v_recipient.skill_name,
          v_recipient.skill_path,
          v_job.reason
        );

        if v_result like 'notified%' then
          v_notified := v_notified + 1;
          v_job_notified := v_job_notified + 1;
        elsif v_result like 'shadow%' then
          v_shadow := v_shadow + 1;
          v_job_notified := v_job_notified + 1;
        elsif v_result like 'suppressed%' then
          v_suppressed := v_suppressed + 1;
        end if;
      end loop;

      update public.possible_match_jobs
      set status = 'done',
          locked_at = null,
          last_error = null,
          notifications_created = notifications_created + v_job_notified,
          updated_at = now()
      where id = v_job.id;
    exception when others then
      v_failed := v_failed + 1;
      v_last_error := left(sqlerrm, 500);
      update public.possible_match_jobs
      set status = case
            when attempts >= v_max_attempts then 'failed'
            else 'pending'
          end,
          run_after = case
            when attempts >= v_max_attempts then run_after
            else now() + make_interval(
              secs => least(300, 30 * (2 ^ greatest(attempts - 1, 0)))
            )
          end,
          locked_at = null,
          last_error = v_last_error,
          updated_at = now()
      where id = v_job.id;
    end;
  end loop;

  -- Read rows are cheap to keep for context, but not forever.
  delete from public.notifications
  where kind = 'possible_match'
    and read_at is not null
    and read_at < now() - make_interval(days => v_retention_days);

  return jsonb_build_object(
    'mode', v_mode,
    'claimed', v_claimed,
    'candidates', v_candidates,
    'notified', v_notified,
    'shadow', v_shadow,
    'suppressed', v_suppressed,
    'failed', v_failed
  );
end;
$$;

revoke all on function public.process_possible_match_jobs(integer)
  from public, anon, authenticated;

-- Cron is the only scheduler. It is intentionally idempotent: every run reaps
-- stale claims and re-checks caps under per-recipient locks.
select cron.unschedule('possible-match-fanout')
where exists (select 1 from cron.job where jobname = 'possible-match-fanout');

select cron.schedule(
  'possible-match-fanout',
  '* * * * *',
  $$select public.process_possible_match_jobs((
    select coalesce((value #>> '{}')::int, 20)
    from public.pipeline_config
    where key = 'possible_match_jobs_per_run'
  ))$$
);
