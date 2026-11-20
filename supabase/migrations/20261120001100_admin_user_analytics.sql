-- User analytics: audience health, activity, engagement, and retention.
--
-- "Active" combines a recent last_seen_at with real app actions (messages or
-- requests) in the selected window. Retention uses signup-week cohorts and the
-- latest last_seen_at, with eligible denominators so recent cohorts are not
-- penalized.

create or replace function public.admin_user_analytics(p_days integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with win as (
  select
    greatest(1, least(coalesce(p_days, 30), 365)) as n,
    current_date - (greatest(1, least(coalesce(p_days, 30), 365)) - 1) as start_d,
    current_date as end_d
),
days as (
  select generate_series(w.start_d, w.end_d, interval '1 day')::date as day from win w
),
activity as (
  select m.sender_id as user_id, m.created_at::date as day
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
  union
  select c.requester_id, c.created_at::date
  from public.connections c, win w
  where c.created_at::date between w.start_d and w.end_d
  union
  select c.recipient_id, c.created_at::date
  from public.connections c, win w
  where c.created_at::date between w.start_d and w.end_d
  union
  select c.requester_id, c.responded_at::date
  from public.connections c, win w
  where c.responded_at is not null
    and c.responded_at::date between w.start_d and w.end_d
  union
  select c.recipient_id, c.responded_at::date
  from public.connections c, win w
  where c.responded_at is not null
    and c.responded_at::date between w.start_d and w.end_d
),
active_users as (
  select distinct a.user_id
  from activity a
  union
  select p.id
  from public.profiles p, win w
  where p.last_seen_at >= w.start_d
),
daily as (
  select
    d.day,
    coalesce(count(distinct a.user_id), 0)::int as active,
    coalesce(count(distinct a.user_id) filter (where p.created_at::date = d.day), 0)::int as new_active,
    coalesce(count(distinct a.user_id) filter (where p.created_at::date < d.day), 0)::int as returning,
    (select count(*) from public.profiles pp where pp.created_at::date = d.day)::int as signups
  from days d
  left join activity a on a.day = d.day
  left join public.profiles p on p.id = a.user_id
  group by d.day
),
summary as (
  select
    (select count(*)::int from public.profiles) as total,
    (select count(*)::int from public.profiles where has_completed_onboarding) as onboarded,
    (select count(*)::int from public.profiles where is_profile_completed) as completed,
    (select count(*)::int from public.profiles p, win w where p.created_at::date between w.start_d and w.end_d) as new_signups,
    (select count(*)::int from active_users) as active,
    (select count(*)::int from public.profiles where last_seen_at >= now() - interval '7 days') as active_7d,
    (select count(*)::int from public.profiles
      where has_completed_onboarding
        and coalesce(last_seen_at, created_at) < now() - interval '30 days') as dormant,
    (select count(*)::int from public.profiles where moderation_status = 'suspended') as suspended,
    (select count(*)::int from public.profiles where moderation_status = 'banned') as banned,
    (select count(*)::int from public.profiles where is_admin) as admins
),
cohorts as (
  select
    date_trunc('week', p.created_at)::date as cohort,
    count(*)::int as size,
    count(*) filter (where p.created_at <= now() - interval '7 days')::int as eligible_7,
    count(*) filter (where p.created_at <= now() - interval '30 days')::int as eligible_30,
    count(*) filter (
      where p.created_at <= now() - interval '7 days'
        and p.last_seen_at >= p.created_at + interval '7 days'
    )::int as d7,
    count(*) filter (
      where p.created_at <= now() - interval '30 days'
        and p.last_seen_at >= p.created_at + interval '30 days'
    )::int as d30
  from public.profiles p
  where p.created_at >= date_trunc('week', now()) - interval '7 weeks'
  group by 1
  order by 1 desc
),
message_counts as (
  select m.sender_id as user_id, count(*)::int as n
  from public.messages m, win w
  where m.created_at::date between w.start_d and w.end_d
  group by m.sender_id
),
request_counts as (
  select c.requester_id as user_id, count(*)::int as n
  from public.connections c, win w
  where c.created_at::date between w.start_d and w.end_d
  group by c.requester_id
),
message_buckets as (
  select
    case when n <= 5 then '1-5' when n <= 20 then '6-20' when n <= 50 then '21-50' else '51+' end as bucket,
    count(*)::int as count,
    min(case when n <= 5 then 1 when n <= 20 then 2 when n <= 50 then 3 else 4 end) as ord
  from message_counts
  group by 1
),
request_buckets as (
  select
    case when n = 1 then '1' when n = 2 then '2' when n <= 5 then '3-5' else '6+' end as bucket,
    count(*)::int as count,
    min(case when n = 1 then 1 when n = 2 then 2 when n <= 5 then 3 else 4 end) as ord
  from request_counts
  group by 1
),
language_counts as (
  select lang as name, count(*)::int as n
  from public.profiles p, unnest(coalesce(p.languages, '{}'::text[])) as lang
  where btrim(lang) <> ''
  group by lang
),
availability_days as (
  select p.id, d.day
  from public.profiles p
  cross join lateral (
    select jsonb_array_elements_text(p.availability) as day
    where jsonb_typeof(p.availability) = 'array'
    union all
    select jsonb_object_keys(p.availability) as day
    where jsonb_typeof(p.availability) = 'object'
  ) d
),
availability_counts as (
  select
    day as name,
    count(*)::int as n,
    min(case lower(day)
      when 'monday' then 1
      when 'tuesday' then 2
      when 'wednesday' then 3
      when 'thursday' then 4
      when 'friday' then 5
      when 'saturday' then 6
      when 'sunday' then 7
      else 8
    end) as ord
  from availability_days
  group by day
),
teaching_style_counts as (
  select style as name, count(*)::int as n
  from public.profiles p, unnest(coalesce(p.teaching_styles, '{}'::text[])) as style
  where btrim(style) <> ''
  group by style
),
learning_style_counts as (
  select style as name, count(*)::int as n
  from public.profiles p, unnest(coalesce(p.learning_styles, '{}'::text[])) as style
  where btrim(style) <> ''
  group by style
),
skill_counts as (
  select p.id, count(us.id)::int as n
  from public.profiles p
  left join public.user_skills us on us.user_id = p.id
  group by p.id
),
skill_buckets as (
  select
    case when n = 0 then '0' when n <= 2 then '1-2' when n <= 5 then '3-5' else '6+' end as bucket,
    count(*)::int as count,
    min(case when n = 0 then 1 when n <= 2 then 2 when n <= 5 then 3 else 4 end) as ord
  from skill_counts
  group by 1
),
country_breakdown as (
  select country_code as code, count(*)::int as n
  from public.profile_locations
  group by country_code
  union all
  select 'Unknown', greatest(0,
    (select count(*) from public.profiles) - (select count(*) from public.profile_locations))
  where (select count(*) from public.profiles) > (select count(*) from public.profile_locations)
),
ph_groups as (
  select public.ph_island_group(region_code, region) as name, count(*)::int as n
  from public.profile_locations
  where country_code = 'PH'
  group by 1
),
ph_cities as (
  select
    coalesce(nullif(btrim(city), ''), 'Unknown city') as name,
    max(region) as region,
    count(*)::int as n
  from public.profile_locations
  where country_code = 'PH'
  group by 1
)
select jsonb_build_object(
  'days', (select n from win),
  'start_day', (select start_d from win),
  'end_day', (select end_d from win),
  'summary', (
    select jsonb_build_object(
      'total', total,
      'onboarded', onboarded,
      'completed', completed,
      'new_signups', new_signups,
      'active', active,
      'active_7d', active_7d,
      'dormant', dormant,
      'suspended', suspended,
      'banned', banned,
      'admins', admins,
      'onboarded_share', case when total > 0 then round(onboarded::numeric / total, 3) end,
      'active_share', case when total > 0 then round(active::numeric / total, 3) end,
      'dormant_share', case when total > 0 then round(dormant::numeric / total, 3) end
    )
    from summary
  ),
  'roles', (
    select jsonb_build_object(
      'mentor', count(*) filter (where role = 'mentor'),
      'learner', count(*) filter (where role = 'learner'),
      'both', count(*) filter (where role = 'both')
    )
    from public.profiles
  ),
  'lifecycle', (
    select jsonb_build_object(
      'never_onboarded', count(*) filter (where not has_completed_onboarding),
      'dormant', count(*) filter (
        where has_completed_onboarding
          and coalesce(last_seen_at, created_at) < now() - interval '30 days'
      ),
      'active_30d', count(*) filter (
        where has_completed_onboarding
          and last_seen_at >= now() - interval '30 days'
      )
    )
    from public.profiles
  ),
  'daily', coalesce((
    select jsonb_agg(to_jsonb(d) order by d.day) from daily d
  ), '[]'::jsonb),
  'retention', coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'cohort', cohort,
        'size', size,
        'eligible_7', eligible_7,
        'eligible_30', eligible_30,
        'd7', d7,
        'd30', d30,
        'd7_share', case when eligible_7 > 0 then round(d7::numeric / eligible_7, 3) end,
        'd30_share', case when eligible_30 > 0 then round(d30::numeric / eligible_30, 3) end
      )
      order by cohort desc
    )
    from cohorts
  ), '[]'::jsonb),
  'messages_per_user', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', count) order by ord)
    from message_buckets
  ), '[]'::jsonb),
  'requests_per_user', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', count) order by ord)
    from request_buckets
  ), '[]'::jsonb),
  'senders', (select count(*)::int from message_counts),
  'requesters', (select count(*)::int from request_counts),
  'profile_health', (
    select jsonb_build_object(
      'missing_avatar', count(*) filter (where avatar_url is null or avatar_url = ''),
      'missing_bio', count(*) filter (where bio is null or btrim(bio) = ''),
      'missing_skills', count(*) filter (
        where not exists (select 1 from public.user_skills us where us.user_id = p.id)
      ),
      'missing_availability', count(*) filter (
        where availability is null or availability = '{}'::jsonb or availability = '[]'::jsonb
      )
    )
    from public.profiles p
  ),
  'timezones', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select coalesce(nullif(timezone, ''), 'Unknown') as name, count(*)::int as n
      from public.profiles
      group by 1
      order by n desc
      limit 8
    ) q
  ), '[]'::jsonb),
  'locations', jsonb_build_object(
    'captured', (select count(*)::int from public.profile_locations),
    'total', (select count(*)::int from public.profiles),
    'coverage', case
      when (select count(*) from public.profiles) > 0
      then round(
        (select count(*) from public.profile_locations)::numeric
        / (select count(*) from public.profiles), 3)
      else null
    end,
    'last_captured_at', (select max(updated_at) from public.profile_locations),
    'countries', coalesce((
      select jsonb_agg(jsonb_build_object('code', code, 'count', n) order by n desc)
      from (
        select * from country_breakdown order by n desc limit 10
      ) q
    ), '[]'::jsonb),
    'ph_total', (select count(*)::int from public.profile_locations where country_code = 'PH'),
    'island_groups', coalesce((
      select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
      from ph_groups
    ), '[]'::jsonb),
    'cities', coalesce((
      select jsonb_agg(jsonb_build_object('name', name, 'region', region, 'count', n) order by n desc)
      from (
        select * from ph_cities order by n desc limit 10
      ) q
    ), '[]'::jsonb)
  ),
  'languages', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select * from language_counts order by n desc limit 10
    ) q
  ), '[]'::jsonb),
  'availability', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by ord)
    from availability_counts
  ), '[]'::jsonb),
  'teaching_styles', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select * from teaching_style_counts order by n desc limit 8
    ) q
  ), '[]'::jsonb),
  'learning_styles', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select * from learning_style_counts order by n desc limit 8
    ) q
  ), '[]'::jsonb),
  'skills_per_user', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', count) order by ord)
    from skill_buckets
  ), '[]'::jsonb)
);
$$;

revoke all on function public.admin_user_analytics(integer) from public, anon, authenticated;
grant execute on function public.admin_user_analytics(integer) to service_role;
