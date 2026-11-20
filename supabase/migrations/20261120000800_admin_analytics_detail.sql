-- Admin analytics detail: richer per-surface payloads.
--
-- Growth and conversations now return jsonb ({ daily, summary, ... }) instead of
-- a bare daily table. Supply returns jsonb (summary + roots + skills + gaps).
-- Safety and system stay jsonb and gain trend, aging, and composition blocks.
--
-- All ranges are derived from p_days (1..365) or calendar windows. No constants
-- are tuned; empty tables return zeros, null rates, and empty arrays.

drop function if exists public.admin_growth(integer);
drop function if exists public.admin_supply();
drop function if exists public.admin_conversations(integer);

create or replace function public.admin_growth(p_days integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
with win as (
  select
    current_date as end_d,
    (current_date - (greatest(1, least(coalesce(p_days, 30), 365)) - 1))::date as start_d,
    greatest(1, least(coalesce(p_days, 30), 365)) as n
),
days as (
  select generate_series(w.start_d, w.end_d, interval '1 day')::date as day from win w
),
signup_daily as (
  select p.created_at::date as day, count(*)::int as n
  from public.profiles p, win w
  where p.created_at::date between w.start_d and w.end_d
  group by 1
),
completion_daily as (
  select p.updated_at::date as day, count(*)::int as n
  from public.profiles p, win w
  where p.has_completed_onboarding
    and p.updated_at::date between w.start_d and w.end_d
  group by 1
),
request_daily as (
  select c.created_at::date as day, count(*)::int as n
  from public.connections c, win w
  where c.created_at::date between w.start_d and w.end_d
  group by 1
),
accepted_daily as (
  select c.responded_at::date as day, count(*)::int as n
  from public.connections c, win w
  where c.status = 'accepted'
    and c.responded_at is not null
    and c.responded_at::date between w.start_d and w.end_d
  group by 1
),
message_daily as (
  select m.created_at::date as day, count(*)::int as n
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
  group by 1
),
sender_daily as (
  select m.created_at::date as day, count(distinct m.sender_id)::int as n
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
  group by 1
),
daily as (
  select
    d.day,
    coalesce(sg.n, 0) as signups,
    coalesce(cp.n, 0) as completed,
    coalesce(rq.n, 0) as requests,
    coalesce(ac.n, 0) as accepted,
    coalesce(ms.n, 0) as messages,
    coalesce(sd.n, 0) as active_senders
  from days d
  left join signup_daily sg on sg.day = d.day
  left join completion_daily cp on cp.day = d.day
  left join request_daily rq on rq.day = d.day
  left join accepted_daily ac on ac.day = d.day
  left join message_daily ms on ms.day = d.day
  left join sender_daily sd on sd.day = d.day
),
totals as (
  select
    coalesce(sum(signups), 0)::int as signups,
    coalesce(sum(completed), 0)::int as completed,
    coalesce(sum(requests), 0)::int as requests,
    coalesce(sum(accepted), 0)::int as accepted,
    coalesce(sum(messages), 0)::int as messages
  from daily
),
cohort as (
  select p.*
  from public.profiles p, win w
  where p.created_at::date between w.start_d and w.end_d
),
activation as (
  select
    count(*)::int as cohort,
    count(*) filter (where has_completed_onboarding)::int as completed,
    count(*) filter (
      where exists (
        select 1 from public.connections c
        where c.requester_id = cohort.id or c.recipient_id = cohort.id
      )
    )::int as requested,
    count(*) filter (
      where exists (
        select 1 from public.connections c
        where (c.requester_id = cohort.id or c.recipient_id = cohort.id)
          and c.status = 'accepted'
      )
    )::int as accepted,
    count(*) filter (
      where exists (select 1 from public.messages m where m.sender_id = cohort.id)
    )::int as messaged
  from cohort
),
cohort_roles as (
  select
    count(*) filter (where role = 'mentor')::int as mentor,
    count(*) filter (where role = 'learner')::int as learner,
    count(*) filter (where role = 'both')::int as both_roles
  from cohort
)
select jsonb_build_object(
  'days', (select n from win),
  'start_day', (select start_d from win),
  'end_day', (select end_d from win),
  'daily', (
    select coalesce(jsonb_agg(to_jsonb(d) order by d.day), '[]'::jsonb) from daily d
  ),
  'summary', (
    select jsonb_build_object(
      'signups', signups,
      'completed', completed,
      'requests', requests,
      'accepted', accepted,
      'messages', messages,
      'active_senders', (
        select count(distinct m.sender_id)
        from public.messages m, win w
        where m.created_at::date between w.start_d and w.end_d
      ),
      'avg_signups_per_day', round(signups::numeric / (select n from win), 2),
      'avg_messages_per_day', round(messages::numeric / (select n from win), 2),
      'accept_rate', case when requests > 0 then accepted::numeric / requests else null end,
      'peak_day', (select day from daily order by signups desc, day desc limit 1),
      'peak_signups', (select signups from daily order by signups desc, day desc limit 1)
    )
    from totals
  ),
  'roles', (
    select jsonb_build_object(
      'mentor', count(*) filter (where role = 'mentor'),
      'learner', count(*) filter (where role = 'learner'),
      'both', count(*) filter (where role = 'both'),
      'total', count(*)
    )
    from public.profiles
  ),
  'cohort_roles', (
    select jsonb_build_object('mentor', mentor, 'learner', learner, 'both', both_roles)
    from cohort_roles
  ),
  'activation', (
    select jsonb_build_object(
      'cohort', cohort,
      'completed', completed,
      'requested', requested,
      'accepted', accepted,
      'messaged', messaged,
      'completed_share', case when cohort > 0 then completed::numeric / cohort else null end,
      'request_share', case when cohort > 0 then requested::numeric / cohort else null end,
      'accepted_share', case when cohort > 0 then accepted::numeric / cohort else null end,
      'messaged_share', case when cohort > 0 then messaged::numeric / cohort else null end
    )
    from activation
  ),
  'top_domains', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select r.name, count(distinct us.user_id)::int as n
      from public.profiles p
      join public.user_skills us on us.user_id = p.id
      join public.skill_nodes sn on sn.id = us.skill_id
      join public.skill_nodes r
        on r.kind = 'category' and r.depth = 1 and sn.path <@ r.path
      where p.created_at::date between (select start_d from win) and (select end_d from win)
      group by r.name
      order by n desc
      limit 8
    ) q
  ), '[]'::jsonb),
  'signups_by_day_of_week', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by idx)
    from (
      select trim(to_char(day, 'Day')) as name,
             extract(isodow from day) as idx,
             sum(signups)::int as n
      from daily
      group by 1, 2
      order by 2
    ) q
  ), '[]'::jsonb)
);
$$;

create or replace function public.admin_supply()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
with roots as (
  select r.id, r.path, r.name
  from public.skill_nodes r
  where r.kind = 'category' and r.depth = 1
),
mentor_skill as (
  select n.id as skill_id, count(distinct us.user_id)::int as n
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  where us.kind = 'teach'
  group by n.id
),
learner_skill as (
  select n.id as skill_id, count(distinct us.user_id)::int as n
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  where us.kind = 'learn'
  group by n.id
),
showcase_skill as (
  select sc.skill_id, count(*)::int as n
  from public.skill_showcases sc
  group by sc.skill_id
),
skill_rows as (
  select
    n.id as skill_id,
    n.name,
    n.path::text as path,
    r.name as root_name,
    r.path::text as root_path,
    coalesce(m.n, 0) as mentors,
    coalesce(l.n, 0) as learners,
    coalesce(s.n, 0) as showcases,
    (coalesce(l.n, 0) - coalesce(m.n, 0)) as gap
  from public.skill_nodes n
  join roots r on n.path <@ r.path
  left join mentor_skill m on m.skill_id = n.id
  left join learner_skill l on l.skill_id = n.id
  left join showcase_skill s on s.skill_id = n.id
  where n.kind = 'skill' and n.status = 'approved'
),
root_rows as (
  select
    r.path::text as root_path,
    r.name as root_name,
    (
      select count(distinct us.user_id)::int
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.kind = 'teach' and n.path <@ r.path
    ) as mentors,
    (
      select count(distinct us.user_id)::int
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.kind = 'learn' and n.path <@ r.path
    ) as learners,
    (
      select count(*)::int
      from public.profiles p
      where p.role = 'both'
        and exists (
          select 1
          from public.user_skills us
          join public.skill_nodes n on n.id = us.skill_id
          where us.user_id = p.id and n.path <@ r.path
        )
    ) as both_roles,
    (
      select count(*)::int
      from public.skill_nodes n
      where n.kind = 'skill' and n.status = 'pending' and n.path <@ r.path
    ) as pending_skills,
    (
      select count(*)::int
      from public.skill_showcases sc
      join public.skill_nodes n on n.id = sc.skill_id
      where n.path <@ r.path
    ) as showcases,
    (
      select count(*)::int
      from public.skill_nodes n
      where n.kind = 'skill' and n.status = 'approved' and n.path <@ r.path
    ) as skills,
    (
      select count(*)::int
      from skill_rows s
      where s.root_path = r.path::text and s.mentors > 0
    ) as covered_skills,
    (
      select count(*)::int
      from skill_rows s
      where s.root_path = r.path::text and s.learners > 0
    ) as demanded_skills
  from roots r
),
totals as (
  select
    (select count(*)::int from public.user_skills where kind = 'teach') as mentor_skills,
    (select count(*)::int from public.user_skills where kind = 'learn') as learner_skills,
    (select count(distinct user_id)::int from public.user_skills where kind = 'teach') as mentors,
    (select count(distinct user_id)::int from public.user_skills where kind = 'learn') as learners,
    (select count(*)::int from public.profiles where role = 'both') as both_roles,
    (select count(*)::int from public.skill_nodes where kind = 'skill' and status = 'approved') as approved_skills,
    (select count(*)::int from public.skill_nodes where kind = 'skill' and status = 'pending') as pending_skills,
    (select count(*)::int from public.skill_showcases) as showcases,
    (select count(*)::int from skill_rows) as skill_rows,
    (select count(*)::int from skill_rows where mentors > 0) as skills_with_mentor,
    (select count(*)::int from skill_rows where learners > 0) as skills_with_learner,
    (select count(*)::int from skill_rows where mentors = 0 and learners > 0) as uncovered_skills,
    (select count(*)::int from skill_rows where learners = 0 and mentors > 0) as idle_supply_skills
)
select jsonb_build_object(
  'summary', (
    select jsonb_build_object(
      'roots', (select count(*) from roots),
      'mentors', mentors,
      'learners', learners,
      'both_roles', both_roles,
      'mentor_skills', mentor_skills,
      'learner_skills', learner_skills,
      'approved_skills', approved_skills,
      'pending_skills', pending_skills,
      'showcases', showcases,
      'skills_with_mentor', skills_with_mentor,
      'skills_with_learner', skills_with_learner,
      'uncovered_skills', uncovered_skills,
      'idle_supply_skills', idle_supply_skills,
      'demand_ratio', case when mentors > 0 then round(learners::numeric / mentors, 2) else null end,
      'mentor_coverage', case when skill_rows > 0 then round(skills_with_mentor::numeric / skill_rows, 3) else null end,
      'showcase_coverage', case when skill_rows > 0 then round((
        select count(*)::numeric from skill_rows where showcases > 0
      ) / skill_rows, 3) else null end
    )
    from totals
  ),
  'roots', coalesce((
    select jsonb_agg(jsonb_build_object(
      'root_path', root_path,
      'root_name', root_name,
      'mentors', mentors,
      'learners', learners,
      'both_roles', both_roles,
      'pending_skills', pending_skills,
      'showcases', showcases,
      'skills', skills,
      'covered_skills', covered_skills,
      'demanded_skills', demanded_skills,
      'demand_ratio', case when mentors > 0 then round(learners::numeric / mentors, 2) else null end,
      'coverage_share', case when skills > 0 then round(covered_skills::numeric / skills, 3) else null end
    ) order by learners desc, mentors desc, root_name)
    from root_rows
  ), '[]'::jsonb),
  'skills', coalesce((
    select jsonb_agg(jsonb_build_object(
      'skill_id', skill_id,
      'name', name,
      'path', path,
      'root_name', root_name,
      'root_path', root_path,
      'mentors', mentors,
      'learners', learners,
      'showcases', showcases,
      'gap', gap
    ) order by learners desc, gap desc, name)
    from skill_rows
  ), '[]'::jsonb),
  'gaps', coalesce((
    select jsonb_agg(jsonb_build_object(
      'skill_id', skill_id,
      'name', name,
      'path', path,
      'root_name', root_name,
      'mentors', mentors,
      'learners', learners,
      'showcases', showcases,
      'gap', gap
    ) order by gap desc, learners desc)
    from (
      select * from skill_rows
      where gap > 0
      order by gap desc, learners desc
      limit 12
    ) g
  ), '[]'::jsonb)
);
$$;

create or replace function public.admin_conversations(p_days integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
with win as (
  select
    current_date as end_d,
    (current_date - (greatest(1, least(coalesce(p_days, 30), 365)) - 1))::date as start_d,
    greatest(1, least(coalesce(p_days, 30), 365)) as n
),
days as (
  select generate_series(w.start_d, w.end_d, interval '1 day')::date as day from win w
),
request_daily as (
  select c.created_at::date as day, count(*)::int as n
  from public.connections c, win w
  where c.created_at::date between w.start_d and w.end_d
  group by 1
),
accepted_daily as (
  select c.responded_at::date as day, count(*)::int as n
  from public.connections c, win w
  where c.status = 'accepted'
    and c.responded_at is not null
    and c.responded_at::date between w.start_d and w.end_d
  group by 1
),
declined_daily as (
  select c.responded_at::date as day, count(*)::int as n
  from public.connections c, win w
  where c.status = 'declined'
    and c.responded_at is not null
    and c.responded_at::date between w.start_d and w.end_d
  group by 1
),
message_daily as (
  select m.created_at::date as day, count(*)::int as n
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
  group by 1
),
chat_daily as (
  select m.created_at::date as day, count(distinct m.connection_id)::int as n
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
  group by 1
),
sender_daily as (
  select m.created_at::date as day, count(distinct m.sender_id)::int as n
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
  group by 1
),
daily as (
  select
    d.day,
    coalesce(rq.n, 0) as requests,
    coalesce(ac.n, 0) as accepted,
    coalesce(dc.n, 0) as declined,
    coalesce(ms.n, 0) as messages,
    coalesce(ct.n, 0) as active_chats,
    coalesce(sd.n, 0) as active_senders
  from days d
  left join request_daily rq on rq.day = d.day
  left join accepted_daily ac on ac.day = d.day
  left join declined_daily dc on dc.day = d.day
  left join message_daily ms on ms.day = d.day
  left join chat_daily ct on ct.day = d.day
  left join sender_daily sd on sd.day = d.day
),
cohort as (
  select c.*
  from public.connections c, win w
  where c.created_at::date between w.start_d and w.end_d
),
cohort_stats as (
  select
    count(*)::int as requests,
    count(*) filter (where responded_at is not null)::int as responded,
    count(*) filter (where status = 'accepted')::int as accepted,
    count(*) filter (where status = 'declined')::int as declined,
    count(*) filter (where status = 'pending')::int as pending,
    count(*) filter (
      where status = 'accepted'
        and not exists (select 1 from public.messages m where m.connection_id = cohort.id)
    )::int as ghosted
  from cohort
),
window_messages as (
  select m.*
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
),
window_chat_sizes as (
  select connection_id, count(*)::int as n
  from window_messages
  group by connection_id
),
chat_buckets as (
  select
    case
      when n <= 5 then '1-5'
      when n <= 20 then '6-20'
      when n <= 50 then '21-50'
      else '51+'
    end as bucket,
    count(*)::int as n,
    min(case when n <= 5 then 1 when n <= 20 then 2 when n <= 50 then 3 else 4 end) as ord
  from window_chat_sizes
  group by 1
),
response_hours as (
  select extract(epoch from (responded_at - created_at)) / 3600 as hours
  from cohort
  where responded_at is not null
),
response_buckets as (
  select
    case
      when hours < 1 then '<1h'
      when hours < 6 then '1-6h'
      when hours < 24 then '6-24h'
      when hours < 72 then '1-3d'
      else '3d+'
    end as bucket,
    count(*)::int as n,
    min(case
      when hours < 1 then 1
      when hours < 6 then 2
      when hours < 24 then 3
      when hours < 72 then 4
      else 5
    end) as ord
  from response_hours
  group by 1
),
first_messages as (
  select c.id, min(m.created_at) as first_at
  from cohort c
  join public.messages m on m.connection_id = c.id
  group by c.id
)
select jsonb_build_object(
  'days', (select n from win),
  'start_day', (select start_d from win),
  'end_day', (select end_d from win),
  'daily', (
    select coalesce(jsonb_agg(to_jsonb(d) order by d.day), '[]'::jsonb) from daily d
  ),
  'summary', (
    select jsonb_build_object(
      'requests', cs.requests,
      'responded', cs.responded,
      'accepted', cs.accepted,
      'declined', cs.declined,
      'pending', cs.pending,
      'ghosted_chats', cs.ghosted,
      'accept_rate', case when cs.requests > 0 then cs.accepted::numeric / cs.requests else null end,
      'decline_rate', case when cs.requests > 0 then cs.declined::numeric / cs.requests else null end,
      'response_rate', case when cs.requests > 0 then cs.responded::numeric / cs.requests else null end,
      'messages', (select count(*)::int from window_messages),
      'active_chats', (select count(*)::int from window_chat_sizes),
      'active_senders', (select count(distinct sender_id)::int from window_messages),
      'avg_messages_per_chat', case
        when (select count(*) from window_chat_sizes) > 0
        then round((select count(*)::numeric from window_messages) / (select count(*) from window_chat_sizes), 2)
        else null
      end,
      'avg_messages_per_day', round(
        (select count(*)::numeric from window_messages) / (select n from win), 2
      ),
      'median_response_hours', (
        select round((percentile_cont(0.5) within group (order by hours))::numeric, 2)
        from response_hours
      ),
      'median_first_message_hours', (
        select round((percentile_cont(0.5) within group (order by hours))::numeric, 2)
        from (
          select extract(epoch from (fm.first_at - c.created_at)) / 3600 as hours
          from first_messages fm
          join cohort c on c.id = fm.id
        ) q
      ),
      'peak_message_day', (select day from daily order by messages desc, day desc limit 1),
      'peak_messages', (select messages from daily order by messages desc, day desc limit 1)
    )
    from cohort_stats cs
  ),
  'status_mix', coalesce((
    select jsonb_object_agg(status, n) from (
      select status::text as status, count(*)::int as n
      from public.connections group by status
    ) q
  ), '{}'::jsonb),
  'funnel', jsonb_build_array(
    jsonb_build_object('step', 'Requests', 'count', (select requests from cohort_stats)),
    jsonb_build_object('step', 'Responded', 'count', (select responded from cohort_stats)),
    jsonb_build_object('step', 'Accepted', 'count', (select accepted from cohort_stats)),
    jsonb_build_object('step', 'Messaged', 'count', (
      select count(distinct c.id)::int
      from cohort c
      join public.messages m on m.connection_id = c.id
    ))
  ),
  'chat_buckets', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', n) order by ord)
    from chat_buckets
  ), '[]'::jsonb),
  'response_buckets', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', n) order by ord)
    from response_buckets
  ), '[]'::jsonb),
  'top_domains', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select r.name, count(*)::int as n
      from cohort c
      join public.skill_nodes r
        on r.kind = 'category' and r.depth = 1 and c.skill_path::ltree <@ r.path
      where c.skill_path is not null and c.skill_path <> ''
      group by r.name
      order by n desc
      limit 8
    ) q
  ), '[]'::jsonb),
  'top_skills', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select coalesce(skill_name, 'Unspecified') as name, count(*)::int as n
      from cohort
      group by 1
      order by n desc
      limit 8
    ) q
  ), '[]'::jsonb)
);
$$;

create or replace function public.admin_safety()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with report_days as (
  select generate_series(current_date - 29, current_date, interval '1 day')::date as day
),
report_daily as (
  select r.created_at::date as day, count(*)::int as n
  from public.reports r
  where r.created_at >= current_date - 29
  group by 1
),
window_daily as (
  select d.day, coalesce(rd.n, 0) as reports
  from report_days d
  left join report_daily rd on rd.day = d.day
),
per_reported as (
  select reported_id, count(*)::int as n
  from public.reports
  group by reported_id
),
reported_buckets as (
  select
    case when n = 1 then '1' when n = 2 then '2' when n <= 5 then '3-5' else '6+' end as bucket,
    count(*)::int as n,
    min(case when n = 1 then 1 when n = 2 then 2 when n <= 5 then 3 else 4 end) as ord
  from per_reported
  group by 1
),
resolution_hours as (
  select extract(epoch from (resolved_at - created_at)) / 3600 as hours
  from public.reports
  where resolved_at is not null
),
resolution_buckets as (
  select
    case
      when hours < 1 then '<1h'
      when hours < 6 then '1-6h'
      when hours < 24 then '6-24h'
      when hours < 72 then '1-3d'
      when hours < 168 then '3-7d'
      else '7d+'
    end as bucket,
    count(*)::int as n,
    min(case
      when hours < 1 then 1
      when hours < 6 then 2
      when hours < 24 then 3
      when hours < 72 then 4
      when hours < 168 then 5
      else 6
    end) as ord
  from resolution_hours
  group by 1
),
open_reports as (
  select * from public.reports where status = 'open'
)
select jsonb_build_object(
  'reports_total', (select count(*) from public.reports),
  'reports_open', (select count(*) from public.reports where status = 'open'),
  'reports_reviewed', (select count(*) from public.reports where status = 'reviewed'),
  'reports_dismissed', (select count(*) from public.reports where status = 'dismissed'),
  'reports_actioned', (select count(*) from public.reports where status = 'actioned'),
  'reports_7d', (
    select count(*) from public.reports where created_at >= now() - interval '7 days'
  ),
  'reports_prev_7d', (
    select count(*) from public.reports
    where created_at >= now() - interval '14 days'
      and created_at < now() - interval '7 days'
  ),
  'reports_30d', (
    select count(*) from public.reports where created_at >= now() - interval '30 days'
  ),
  'daily_reports', coalesce((
    select jsonb_agg(jsonb_build_object('day', day, 'reports', reports) order by day)
    from window_daily
  ), '[]'::jsonb),
  'status_mix', coalesce((
    select jsonb_object_agg(status, n) from (
      select status, count(*)::int as n from public.reports group by status
    ) q
  ), '{}'::jsonb),
  'reports_by_reason', coalesce((
    select jsonb_object_agg(reason, n) from (
      select reason, count(*)::int as n
      from public.reports group by reason order by n desc limit 10
    ) q
  ), '{}'::jsonb),
  'action_mix', coalesce((
    select jsonb_object_agg(action_taken, n) from (
      select action_taken, count(*)::int as n
      from public.reports
      where action_taken is not null and action_taken <> ''
      group by action_taken order by n desc limit 10
    ) q
  ), '{}'::jsonb),
  'resolution_mix', coalesce((
    select jsonb_object_agg(resolution, n) from (
      select resolution, count(*)::int as n
      from public.reports
      where resolution is not null and resolution <> ''
      group by resolution order by n desc limit 8
    ) q
  ), '{}'::jsonb),
  'resolution_buckets', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', n) order by ord)
    from resolution_buckets
  ), '[]'::jsonb),
  'open_aging', jsonb_build_object(
    'over_24h', (select count(*) from open_reports where created_at < now() - interval '24 hours'),
    'over_7d', (select count(*) from open_reports where created_at < now() - interval '7 days'),
    'over_30d', (select count(*) from open_reports where created_at < now() - interval '30 days'),
    'oldest_hours', (
      select round(max(extract(epoch from (now() - created_at)) / 3600)::numeric, 1)
      from open_reports
    )
  ),
  'reports_per_reported', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', n) order by ord)
    from reported_buckets
  ), '[]'::jsonb),
  'top_reported', coalesce((
    select jsonb_agg(jsonb_build_object(
      'user_id', user_id, 'name', name, 'reports', n, 'open', open_n, 'last_report_at', last_at
    ) order by n desc, last_at desc)
    from (
      select
        r.reported_id as user_id,
        coalesce(max(p.display_name), 'Deleted profile') as name,
        count(*)::int as n,
        count(*) filter (where r.status = 'open')::int as open_n,
        max(r.created_at) as last_at
      from public.reports r
      left join public.profiles p on p.id = r.reported_id
      group by r.reported_id
      order by n desc, last_at desc
      limit 8
    ) q
  ), '[]'::jsonb),
  'blocks', (select count(*) from public.blocks),
  'blocks_7d', (select count(*) from public.blocks where created_at >= now() - interval '7 days'),
  'blocks_30d', (select count(*) from public.blocks where created_at >= now() - interval '30 days'),
  'pending_skills', (select count(*) from public.skill_nodes where kind = 'skill' and status = 'pending'),
  'pending_notes', (select count(*) from public.note_moderation_queue where status = 'pending'),
  'queue_aging', jsonb_build_object(
    'skills_over_7d', (
      select count(*) from public.skill_nodes
      where kind = 'skill' and status = 'pending' and created_at < now() - interval '7 days'
    ),
    'oldest_skill_hours', (
      select round(max(extract(epoch from (now() - created_at)) / 3600)::numeric, 1)
      from public.skill_nodes where kind = 'skill' and status = 'pending'
    ),
    'notes_over_7d', (
      select count(*) from public.note_moderation_queue
      where status = 'pending' and created_at < now() - interval '7 days'
    ),
    'oldest_note_hours', (
      select round(max(extract(epoch from (now() - created_at)) / 3600)::numeric, 1)
      from public.note_moderation_queue where status = 'pending'
    )
  ),
  'avg_resolution_hours', (
    select avg(extract(epoch from (resolved_at - created_at)) / 3600)
    from public.reports where resolved_at is not null
  ),
  'avg_resolution_hours_30d', (
    select avg(extract(epoch from (resolved_at - created_at)) / 3600)
    from public.reports
    where resolved_at is not null and created_at >= now() - interval '30 days'
  ),
  'median_resolution_hours', (
    select percentile_cont(0.5) within group (
      order by extract(epoch from (resolved_at - created_at)) / 3600
    )
    from public.reports where resolved_at is not null
  ),
  'resolved_count', (select count(*) from public.reports where resolved_at is not null),
  'resolved_30d', (
    select count(*) from public.reports
    where resolved_at is not null and resolved_at >= now() - interval '30 days'
  ),
  'repeat_reporters', coalesce((
    select count(*) from (
      select reported_id from public.reports group by reported_id having count(*) >= 3
    ) q
  ), 0)
);
$$;

create or replace function public.admin_system()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with error_days as (
  select generate_series(current_date - 13, current_date, interval '1 day')::date as day
),
error_daily as (
  select e.created_at::date as day, count(*)::int as n
  from public.client_errors e
  where e.created_at >= current_date - 13
  group by 1
),
error_window as (
  select d.day, coalesce(ed.n, 0) as errors
  from error_days d
  left join error_daily ed on ed.day = d.day
),
cache as (
  select
    count(*)::int as rows,
    max(refreshed_at) as last_refresh,
    count(*) filter (where refreshed_at < now() - interval '24 hours')::int as stale_rows
  from public.match_cache
),
profile_counts as (
  select
    count(*)::int as total,
    count(*) filter (where has_completed_onboarding)::int as onboarded,
    count(*) filter (where is_profile_completed)::int as completed,
    count(*) filter (where moderation_status = 'suspended')::int as suspended,
    count(*) filter (where moderation_status = 'banned')::int as banned
  from public.profiles
),
embedding as (
  select
    count(*)::int as rows,
    count(distinct user_id)::int as users
  from public.profile_embeddings
)
select jsonb_build_object(
  'profiles_total', (select total from profile_counts),
  'profiles_onboarded', (select onboarded from profile_counts),
  'profiles_completed', (select completed from profile_counts),
  'profiles_suspended', (select suspended from profile_counts),
  'profiles_banned', (select banned from profile_counts),
  'embeddings', (select rows from embedding),
  'embedding_users', (select users from embedding),
  'embedding_coverage', case
    when (select onboarded from profile_counts) > 0
    then round(least(
      1,
      (select users from embedding)::numeric / (select onboarded from profile_counts)
    ), 3)
    else null
  end,
  'profiles_without_embedding', (
    select count(*) from public.profiles p
    where p.has_completed_onboarding
      and not exists (select 1 from public.profile_embeddings e where e.user_id = p.id)
  ),
  'cache_rows', (select rows from cache),
  'cache_last_refresh', (select last_refresh from cache),
  'cache_age_minutes', (
    select round(extract(epoch from (now() - last_refresh)) / 60)
    from cache where last_refresh is not null
  ),
  'stale_cache_rows', (select stale_rows from cache),
  'cache_by_role', coalesce((
    select jsonb_object_agg(as_role, n) from (
      select as_role::text as as_role, count(*)::int as n
      from public.match_cache group by as_role
    ) q
  ), '{}'::jsonb),
  'cache_by_pipeline', coalesce((
    select jsonb_object_agg(pipeline_mode, n) from (
      select pipeline_mode, count(*)::int as n
      from public.match_cache group by pipeline_mode
    ) q
  ), '{}'::jsonb),
  'config_revision', (select max(config_version) from public.pipeline_config),
  'config_keys', (select count(*)::int from public.pipeline_config),
  'config_updated_at', (select max(updated_at) from public.pipeline_config),
  'notifications_total', (select count(*)::int from public.notifications),
  'notifications_unread', (select count(*)::int from public.notifications where read_at is null),
  'notifications_7d', (
    select count(*)::int from public.notifications where created_at >= now() - interval '7 days'
  ),
  'table_counts', jsonb_build_array(
    jsonb_build_object('name', 'profiles', 'count', (select count(*) from public.profiles)),
    jsonb_build_object('name', 'connections', 'count', (select count(*) from public.connections)),
    jsonb_build_object('name', 'messages', 'count', (select count(*) from public.messages)),
    jsonb_build_object('name', 'notifications', 'count', (select count(*) from public.notifications)),
    jsonb_build_object('name', 'reports', 'count', (select count(*) from public.reports)),
    jsonb_build_object('name', 'blocks', 'count', (select count(*) from public.blocks)),
    jsonb_build_object('name', 'skills', 'count', (select count(*) from public.skill_nodes where kind = 'skill')),
    jsonb_build_object('name', 'showcases', 'count', (select count(*) from public.skill_showcases)),
    jsonb_build_object('name', 'match_cache', 'count', (select count(*) from public.match_cache))
  ),
  'client_errors_7d', (
    select count(*) from public.client_errors where created_at >= now() - interval '7 days'
  ),
  'client_errors_prev_7d', (
    select count(*) from public.client_errors
    where created_at >= now() - interval '14 days'
      and created_at < now() - interval '7 days'
  ),
  'error_daily', coalesce((
    select jsonb_agg(jsonb_build_object('day', day, 'errors', errors) order by day)
    from error_window
  ), '[]'::jsonb),
  'top_client_errors', coalesce((
    select jsonb_agg(jsonb_build_object('message', message, 'count', n) order by n desc)
    from (
      select left(message, 180) as message, count(*)::int as n
      from public.client_errors
      where created_at >= now() - interval '7 days'
      group by 1 order by n desc limit 8
    ) q
  ), '[]'::jsonb),
  'top_error_routes', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select coalesce(route, 'unknown') as name, count(*)::int as n
      from public.client_errors
      where created_at >= now() - interval '7 days'
      group by 1 order by n desc limit 8
    ) q
  ), '[]'::jsonb),
  'error_platforms', coalesce((
    select jsonb_object_agg(name, n) from (
      select coalesce(platform, 'unknown') as name, count(*)::int as n
      from public.client_errors
      where created_at >= now() - interval '7 days'
      group by 1 order by n desc limit 8
    ) q
  ), '{}'::jsonb),
  'rate_limit_hits', coalesce((
    select jsonb_object_agg(action, n) from (
      select action, sum(count)::int as n
      from public.rate_limits group by action order by n desc limit 10
    ) q
  ), '{}'::jsonb),
  'job_status', coalesce((
    select jsonb_object_agg(status, n) from (
      select status, count(*)::int as n
      from public.possible_match_jobs group by status
    ) q
  ), '{}'::jsonb),
  'jobs_oldest_pending_minutes', (
    select round(extract(epoch from (now() - min(created_at))) / 60)
    from public.possible_match_jobs where status = 'pending'
  )
);
$$;

revoke all on function public.admin_growth(integer) from public, anon, authenticated;
revoke all on function public.admin_supply() from public, anon, authenticated;
revoke all on function public.admin_conversations(integer) from public, anon, authenticated;
revoke all on function public.admin_safety() from public, anon, authenticated;
revoke all on function public.admin_system() from public, anon, authenticated;

grant execute on function public.admin_growth(integer) to service_role;
grant execute on function public.admin_supply() to service_role;
grant execute on function public.admin_conversations(integer) to service_role;
grant execute on function public.admin_safety() to service_role;
grant execute on function public.admin_system() to service_role;
