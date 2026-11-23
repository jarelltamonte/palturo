-- Overview reads the same cache as Matching analytics, and it was still reading
-- the legacy `match_cache`, which cards mode never writes. Mirror the analytics
-- rule: prefer v2, fall back to v1 so a rollback to profile/gated mode still
-- reports something.

create or replace function public.admin_overview()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with cache as (
    select rerank_score_b, calibrated_score
    from public.match_cache_v2
    union all
    select rerank_score_b, calibrated_score
    from public.match_cache
    where not exists (select 1 from public.match_cache_v2)
  )
  select jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'onboarded', (select count(*) from public.profiles where has_completed_onboarding),
    'mentors', (select count(*) from public.profiles where role = 'mentor'),
    'learners', (select count(*) from public.profiles where role = 'learner'),
    'both', (select count(*) from public.profiles where role = 'both'),
    'new_7d', (select count(*) from public.profiles where created_at >= now() - interval '7 days'),
    'pending_requests', (select count(*) from public.connections where status = 'pending'),
    'accepted_requests', (select count(*) from public.connections where status = 'accepted'),
    'declined_requests', (select count(*) from public.connections where status = 'declined'),
    'messages', (select count(*) from public.messages),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'blocks', (select count(*) from public.blocks),
    'approved_skills', (select count(*) from public.skill_nodes where kind = 'skill' and status = 'approved'),
    'pending_skills', (select count(*) from public.skill_nodes where kind = 'skill' and status = 'pending'),
    'showcases', (select count(*) from public.skill_showcases),
    'cache_rows', (select count(*) from cache),
    'a_only_share', coalesce((select avg(case when rerank_score_b is null then 1 else 0 end) from cache), 0),
    'avg_compatibility', coalesce((select avg(calibrated_score) from cache), 0),
    'embeddings', (select count(*) from public.profile_embeddings),
    'client_errors_7d', (select count(*) from public.client_errors where created_at >= now() - interval '7 days')
  );
$$;
