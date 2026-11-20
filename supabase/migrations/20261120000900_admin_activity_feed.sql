-- App activity feed: chronological product events, separate from the admin audit.
--
-- Derived from app tables only, so it reflects what happened inside PalTuro
-- (signups, onboarding, skills, requests, chats, safety) rather than what an
-- administrator clicked. Account deletions are the one exception: Supabase
-- removes the profile row, so the recorded deletion in admin_audit_log is the
-- only surviving evidence and is surfaced as an app event.

create or replace function public.admin_activity(p_days integer default 14)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
with win as (
  select
    greatest(1, least(coalesce(p_days, 14), 365)) as n,
    now() - make_interval(days => greatest(1, least(coalesce(p_days, 14), 365))) as since
),
names as (
  select
    p.id,
    coalesce(
      nullif(p.display_name, ''),
      nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
      'Unnamed'
    ) as name
  from public.profiles p
),
events as (
  select
    p.created_at as occurred_at,
    'users'::text as category,
    'signup'::text as kind,
    'New signup'::text as title,
    concat_ws(
      ' · ',
      nullif(p.role::text, ''),
      case when p.has_completed_onboarding then 'onboarded' else 'onboarding pending' end
    ) as detail,
    n.name as subject,
    p.id::text as subject_id
  from public.profiles p
  join names n on n.id = p.id
  cross join win w
  where p.created_at >= w.since

  union all

  select
    p.updated_at,
    'users',
    'profile_updated',
    'Profile updated',
    p.role::text,
    n.name,
    p.id::text
  from public.profiles p
  join names n on n.id = p.id
  cross join win w
  where p.updated_at >= w.since
    and p.updated_at > p.created_at + interval '5 minutes'
    and (p.name_changed_at is null or p.name_changed_at <> p.updated_at)
    and (p.suspended_at is null or p.suspended_at <> p.updated_at)
    and (p.last_warned_at is null or p.last_warned_at <> p.updated_at)

  union all

  select
    p.name_changed_at,
    'users',
    'name_changed',
    'Name changed',
    nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
    n.name,
    p.id::text
  from public.profiles p
  join names n on n.id = p.id
  cross join win w
  where p.name_changed_at is not null
    and p.name_changed_at >= w.since

  union all

  select
    f.created_at,
    'users',
    'app_feedback',
    'App feedback submitted',
    f.kind,
    coalesce(n.name, 'Unknown'),
    f.user_id::text
  from public.app_feedback f
  left join names n on n.id = f.user_id
  cross join win w
  where f.created_at >= w.since

  union all

  select
    a.created_at,
    'users',
    'account_deleted',
    'Account deleted',
    concat_ws(' · ', 'admin console', nullif(a.actor_email, '')),
    left(a.target_id, 8),
    a.target_id
  from public.admin_audit_log a
  cross join win w
  where a.action = 'user.delete'
    and a.created_at >= w.since

  union all

  select
    s.created_at,
    'skills',
    case when s.status = 'pending' then 'skill_submitted' else 'skill_added' end,
    case when s.status = 'pending' then 'Skill submitted' else 'Skill added' end,
    concat_ws(' · ', s.path::text, nullif(s.origin::text, '')),
    s.name,
    s.id::text
  from public.skill_nodes s
  cross join win w
  where s.kind = 'skill'
    and s.created_at >= w.since

  union all

  select
    sc.created_at,
    'skills',
    'showcase_saved',
    'Showcase saved',
    sk.name,
    n.name,
    sc.user_id::text
  from public.skill_showcases sc
  join public.skill_nodes sk on sk.id = sc.skill_id
  join names n on n.id = sc.user_id
  cross join win w
  where sc.created_at >= w.since

  union all

  select
    us.created_at,
    'skills',
    'profile_skill_added',
    'Skill added to profile',
    concat_ws(
      ' · ',
      sn.name,
      case when us.kind = 'teach' then 'teaching' else 'learning' end
    ),
    coalesce(n.name, 'Unknown'),
    us.user_id::text
  from public.user_skills us
  join public.skill_nodes sn on sn.id = us.skill_id
  left join names n on n.id = us.user_id
  cross join win w
  where us.created_at >= w.since

  union all

  select
    c.created_at,
    'requests',
    'request_sent',
    'Intro request sent',
    concat_ws(' · ', nullif(c.skill_name, ''), 'to ' || recip.name),
    req.name,
    c.id::text
  from public.connections c
  join names req on req.id = c.requester_id
  join names recip on recip.id = c.recipient_id
  cross join win w
  where c.created_at >= w.since

  union all

  select
    c.responded_at,
    'requests',
    'request_accepted',
    'Request accepted',
    concat_ws(' · ', nullif(c.skill_name, ''), req.name || ' ↔ ' || recip.name),
    recip.name,
    c.id::text
  from public.connections c
  join names req on req.id = c.requester_id
  join names recip on recip.id = c.recipient_id
  cross join win w
  where c.status = 'accepted'
    and c.responded_at is not null
    and c.responded_at >= w.since

  union all

  select
    c.responded_at,
    'requests',
    'request_declined',
    'Request declined',
    concat_ws(' · ', nullif(c.skill_name, ''), req.name || ' ↔ ' || recip.name),
    recip.name,
    c.id::text
  from public.connections c
  join names req on req.id = c.requester_id
  join names recip on recip.id = c.recipient_id
  cross join win w
  where c.status = 'declined'
    and c.responded_at is not null
    and c.responded_at >= w.since

  union all

  select
    c.unmatched_at,
    'requests',
    'unmatched',
    'Connection unmatched',
    nullif(c.skill_name, ''),
    req.name,
    c.id::text
  from public.connections c
  join names req on req.id = c.requester_id
  cross join win w
  where c.unmatched_at is not null
    and c.unmatched_at >= w.since

  union all

  select
    m.created_at,
    'chats',
    'chat_started',
    'Conversation started',
    nullif(c.skill_name, ''),
    n.name,
    c.id::text
  from public.messages m
  join public.connections c on c.id = m.connection_id
  join names n on n.id = m.sender_id
  cross join win w
  where m.created_at >= w.since
    and not exists (
      select 1
      from public.messages pm
      where pm.connection_id = m.connection_id
        and pm.created_at < m.created_at
    )

  union all

  select
    f.created_at,
    'chats',
    'feedback_submitted',
    'Feedback submitted',
    concat_ws(
      ' · ',
      'Clarity ' || f.clarity_of_instruction,
      'Reliability ' || f.reliability
    ),
    coalesce(n.name, 'Unknown'),
    f.connection_id::text
  from public.feedback f
  left join names n on n.id = f.rater_id
  cross join win w
  where f.created_at >= w.since

  union all

  select
    r.created_at,
    'safety',
    'report_filed',
    'Report filed',
    concat_ws(' · ', nullif(r.reason, ''), nullif(r.status, '')),
    coalesce(rn.name, 'Unnamed'),
    r.reported_id::text
  from public.reports r
  left join names rn on rn.id = r.reported_id
  cross join win w
  where r.created_at >= w.since

  union all

  select
    r.resolved_at,
    'safety',
    'report_resolved',
    'Report resolved',
    concat_ws(
      ' · ',
      nullif(r.reason, ''),
      nullif(r.action_taken, ''),
      nullif(r.resolution, '')
    ),
    coalesce(rn.name, 'Unnamed'),
    r.reported_id::text
  from public.reports r
  left join names rn on rn.id = r.reported_id
  cross join win w
  where r.resolved_at is not null
    and r.resolved_at >= w.since

  union all

  select
    b.created_at,
    'safety',
    'block',
    'User blocked',
    bn.name || ' blocked ' || bl.name,
    bn.name,
    b.blocker_id::text
  from public.blocks b
  join names bn on bn.id = b.blocker_id
  join names bl on bl.id = b.blocked_id
  cross join win w
  where b.created_at >= w.since

  union all

  select
    ma.created_at,
    'safety',
    'moderation_' || ma.action,
    'Moderation: ' || ma.action,
    nullif(ma.reason, ''),
    coalesce(n.name, 'Unnamed'),
    ma.user_id::text
  from public.moderation_actions ma
  left join names n on n.id = ma.user_id
  cross join win w
  where ma.created_at >= w.since
    and ma.action <> 'pass'
)
select jsonb_build_object(
  'days', (select n from win),
  'generated_at', now(),
  'total', (select count(*) from events),
  'categories', coalesce((
    select jsonb_agg(jsonb_build_object('id', category, 'count', n) order by category)
    from (
      select category, count(*)::int as n
      from events
      group by category
    ) q
  ), '[]'::jsonb),
  'kinds', coalesce((
    select jsonb_agg(
      jsonb_build_object('category', category, 'kind', kind, 'count', n)
      order by category, kind
    )
    from (
      select category, kind, count(*)::int as n
      from events
      group by category, kind
    ) q
  ), '[]'::jsonb),
  'events', coalesce((
    select jsonb_agg(to_jsonb(e) order by e.occurred_at desc)
    from (
      select *
      from events
      order by occurred_at desc
      limit 500
    ) e
  ), '[]'::jsonb)
);
$$;

revoke all on function public.admin_activity(integer) from public, anon, authenticated;
grant execute on function public.admin_activity(integer) to service_role;
