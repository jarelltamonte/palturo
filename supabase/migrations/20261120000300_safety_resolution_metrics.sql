-- Resolution metrics: robust 30-day average, median, and resolved counts.
create or replace function public.admin_safety()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'reports_open', (select count(*) from public.reports where status = 'open'),
    'reports_reviewed', (select count(*) from public.reports where status = 'reviewed'),
    'reports_dismissed', (select count(*) from public.reports where status = 'dismissed'),
    'reports_actioned', (select count(*) from public.reports where status = 'actioned'),
    'reports_by_reason', coalesce((
      select jsonb_object_agg(reason, n) from (
        select reason, count(*)::int as n from public.reports group by reason order by n desc limit 10
      ) q
    ), '{}'::jsonb),
    'blocks', (select count(*) from public.blocks),
    'pending_skills', (select count(*) from public.skill_nodes where kind = 'skill' and status = 'pending'),
    'pending_notes', (select count(*) from public.note_moderation_queue where status = 'pending'),
    'avg_resolution_hours', (
      select avg(extract(epoch from (resolved_at - created_at)) / 3600)
      from public.reports where resolved_at is not null
    ),
    'avg_resolution_hours_30d', (
      select avg(extract(epoch from (resolved_at - created_at)) / 3600)
      from public.reports
      where resolved_at is not null
        and created_at >= now() - interval '30 days'
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

revoke all on function public.admin_safety() from public, anon, authenticated;
grant execute on function public.admin_safety() to service_role;
