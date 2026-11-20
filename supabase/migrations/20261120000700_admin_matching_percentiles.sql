-- Matching analytics: empirical pair percentiles plus per-skill breakdowns.
-- Scope: this function only. No consumer matcher or cache writes.
--
-- Percentile is cume_dist() over the current cached pair population:
-- "fraction of cached pairs scoring at or below this pair".
-- It is strictly non-decreasing with score, so ranking is unchanged.

create or replace function public.admin_matching()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
with scored as (
  select
    mc.*,
    cume_dist() over (order by mc.calibrated_score) as score_percentile
  from public.match_cache mc
),
skill_rows as (
  select
    s.*,
    n.id as skill_id,
    n.name as skill_name,
    n.path as skill_path
  from scored s
  join public.user_skills us
    on us.user_id = s.candidate_id
   and us.kind = case
     when s.as_role = 'mentor' then 'teach'::public.skill_kind
     else 'learn'::public.skill_kind
   end
  join public.skill_nodes n
    on n.id = us.skill_id
   and n.kind = 'skill'
),
skill_agg as (
  select
    skill_id,
    skill_name,
    skill_path,
    count(*)::int as pairs,
    avg(calibrated_score) as avg_score,
    avg(reciprocal_score) as avg_raw,
    max(calibrated_score) as max_score,
    min(calibrated_score) as min_score,
    avg(score_percentile) as avg_percentile,
    avg(score_percentile) filter (where rank <= 5) as top5_avg_percentile,
    avg(case when bi_score = 0 then 1 else 0 end) as fallback_share,
    avg(case when rerank_score_b is null then 1 else 0 end) as a_only_share,
    count(*) filter (where as_role = 'mentor')::int as mentor_pairs,
    count(*) filter (where as_role = 'learner')::int as learner_pairs
  from skill_rows
  group by skill_id, skill_name, skill_path
),
skill_buckets as (
  select
    skill_id,
    width_bucket(calibrated_score, 0, 1, 5) as bucket,
    count(*)::int as n
  from skill_rows
  group by skill_id, bucket
),
skill_stats as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'skill_id', a.skill_id,
        'name', a.skill_name,
        'path', a.skill_path,
        'pairs', a.pairs,
        'avg_score', a.avg_score,
        'avg_raw', a.avg_raw,
        'max_score', a.max_score,
        'min_score', a.min_score,
        'avg_percentile', a.avg_percentile,
        'top5_avg_percentile', a.top5_avg_percentile,
        'fallback_share', a.fallback_share,
        'a_only_share', a.a_only_share,
        'mentor_pairs', a.mentor_pairs,
        'learner_pairs', a.learner_pairs,
        'score_buckets', coalesce((
          select jsonb_agg(
            jsonb_build_object('bucket', b.bucket, 'count', b.n)
            order by b.bucket
          )
          from skill_buckets b
          where b.skill_id = a.skill_id
        ), '[]'::jsonb)
      )
      order by a.avg_score desc, a.pairs desc
    ),
    '[]'::jsonb
  ) as rows
  from skill_agg a
),
top_pairs as (
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'viewer', viewer_name,
        'candidate', candidate_name,
        'as_role', as_role,
        'score', calibrated_score,
        'raw', reciprocal_score,
        'percentile', score_percentile,
        'rank', rank
      )
      order by calibrated_score desc
    ),
    '[]'::jsonb
  ) as rows
  from (
    select
      s.*,
      p.display_name as viewer_name,
      s.display_name as candidate_name
    from scored s
    left join public.profiles p on p.id = s.user_id
    order by s.calibrated_score desc
    limit 5
  ) t
)
select jsonb_build_object(
  'cache_rows', (select count(*) from scored),
  'a_only_share', coalesce((
    select avg(case when rerank_score_b is null then 1 else 0 end) from scored
  ), 0),
  'avg_compatibility', (select avg(calibrated_score) from scored),
  'avg_raw_reciprocal', (select avg(reciprocal_score) from scored),
  'avg_top5_percentile', (
    select avg(score_percentile) from scored where rank <= 5
  ),
  'avg_top5_raw', (
    select avg(reciprocal_score) from scored where rank <= 5
  ),
  'fallback_share', (
    select avg(case when bi_score = 0 then 1 else 0 end) from scored
  ),
  'max_compatibility', (select max(calibrated_score) from scored),
  'min_compatibility', (select min(calibrated_score) from scored),
  'median_compatibility', (
    select percentile_cont(0.5) within group (order by calibrated_score)
    from scored
  ),
  'top5_rows', (select count(*) from scored where rank <= 5),
  'role_pairs', jsonb_build_object(
    'mentor', (select count(*) from scored where as_role = 'mentor'),
    'learner', (select count(*) from scored where as_role = 'learner')
  ),
  'pipeline_modes', coalesce((
    select jsonb_object_agg(mode, n) from (
      select pipeline_mode as mode, count(*)::int as n
      from scored group by pipeline_mode
    ) q
  ), '{}'::jsonb),
  'score_buckets', coalesce((
    select jsonb_agg(jsonb_build_object('bucket', bucket, 'count', n) order by bucket)
    from (
      select width_bucket(calibrated_score, 0, 1, 5) as bucket, count(*)::int as n
      from scored group by 1
    ) q
  ), '[]'::jsonb),
  'top_domains', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select r.name, count(*)::int as n
      from skill_rows sr
      join public.skill_nodes r
        on r.kind = 'category' and r.depth = 1 and sr.skill_path <@ r.path
      group by r.name
      order by n desc
      limit 8
    ) q
  ), '[]'::jsonb),
  'top_skills', coalesce((
    select jsonb_agg(jsonb_build_object('name', name, 'count', n) order by n desc)
    from (
      select skill_name as name, count(*)::int as n
      from skill_rows
      group by skill_name
      order by n desc
      limit 8
    ) q
  ), '[]'::jsonb),
  'top_pairs', (select rows from top_pairs),
  'lowest_pair', (
    select jsonb_build_object(
      'viewer', viewer_name,
      'candidate', candidate_name,
      'as_role', as_role,
      'score', calibrated_score,
      'raw', reciprocal_score,
      'percentile', score_percentile,
      'rank', rank
    )
    from (
      select
        s.*,
        p.display_name as viewer_name,
        s.display_name as candidate_name
      from scored s
      left join public.profiles p on p.id = s.user_id
      order by s.calibrated_score asc
      limit 1
    ) t
  ),
  'skill_stats', (select rows from skill_stats)
);
$$;

revoke all on function public.admin_matching() from public, anon, authenticated;
grant execute on function public.admin_matching() to service_role;
