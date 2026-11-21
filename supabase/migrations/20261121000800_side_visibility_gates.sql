-- Per-side discovery readiness.
--
-- A profile is discoverable only on a side that is ready:
--   * learner side: every approved learning skill has an approved note.
--   * mentor side: showcase media exists and every approved teaching skill has
--     an approved note.
--
-- This is deliberately per side, not one global flag: a `both` profile can be
-- visible as a learner while hidden as a mentor. Onboarding collects learner
-- notes up front; teaching notes are added afterwards from Profile.

create or replace function public.side_notes_complete(
  p_user uuid,
  p_kind public.skill_kind
)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select not exists (
    select 1
    from public.user_skills us
    join public.skill_nodes n on n.id = us.skill_id
    where us.user_id = p_user
      and us.kind = p_kind
      and n.kind = 'skill'
      and n.status = 'approved'
      and (
        us.note is null
        or btrim(us.note) = ''
        or not coalesce(us.note_approved, false)
      )
  );
$$;

-- The showcase gate now also requires the teaching-side notes. Keeping this in
-- has_discovery_media means every existing mentor gate picks up the note
-- requirement without each call site re-implementing it.
create or replace function public.has_discovery_media(p_user uuid)
returns boolean
language sql
stable
set search_path to 'public'
as $$
  select public.side_notes_complete(p_user, 'teach')
    and (
      not exists (
        select 1 from public.user_skills us
        where us.user_id = p_user and us.kind = 'teach'
      )
      or exists (
        select 1 from public.skill_showcases s where s.user_id = p_user
      )
      or coalesce((
        select p.teaching_skill_images <> '{}'::jsonb
        from public.profiles p where p.id = p_user
      ), false)
    );
$$;

-- A side is ready only when it actually has an approved skill and every such
-- skill has an approved note. Requiring the skill keeps an empty side from
-- being "vacuously ready" (a teaching-only profile must not look learner-ready).
create or replace function public.side_ready(
  p_user uuid,
  p_kind public.skill_kind
)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
      select 1
      from public.user_skills us
      join public.skill_nodes n on n.id = us.skill_id
      where us.user_id = p_user
        and us.kind = p_kind
        and n.kind = 'skill'
        and n.status = 'approved'
    )
    and public.side_notes_complete(p_user, p_kind)
    and (
      p_kind = 'learn'
      or public.has_discovery_media(p_user)
    );
$$;

revoke all on function public.side_notes_complete(uuid, public.skill_kind)
  from public, anon, authenticated;
revoke all on function public.side_ready(uuid, public.skill_kind)
  from public, anon, authenticated;
revoke all on function public.has_discovery_media(uuid)
  from public, anon, authenticated;

-- Approval and note edits change discovery visibility and embedded context, so
-- cached decks must not keep the old answer.
create or replace function public.invalidate_note_visibility_cache()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'UPDATE'
     and new.note is not distinct from old.note
     and new.note_approved is not distinct from old.note_approved then
    return null;
  end if;

  delete from public.match_cache
  where user_id = new.user_id or candidate_id = new.user_id;

  return null;
end;
$$;

drop trigger if exists trg_user_skills_note_cache on public.user_skills;
create trigger trg_user_skills_note_cache
  after insert or update of note, note_approved on public.user_skills
  for each row
  execute function public.invalidate_note_visibility_cache();

revoke all on function public.invalidate_note_visibility_cache()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------

create or replace function public.browse_skill_users(
  p_node text,
  p_kind public.skill_kind default 'teach',
  p_limit integer default 50
)
returns table (
  user_id uuid,
  name text,
  role text,
  avatar_url text,
  note text,
  availability jsonb,
  languages text[],
  learning_styles text[],
  teaching_styles text[],
  skill_name text,
  skill_path text,
  showcases jsonb
)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
  select distinct on (us.user_id)
    us.user_id,
    coalesce(p.display_name, ''),
    p.role::text,
    p.avatar_url,
    case when us.note_approved then us.note else null end,
    coalesce(p.availability, '{}'::jsonb),
    coalesce(p.languages, '{}'::text[]),
    coalesce(p.learning_styles, '{}'::text[]),
    coalesce(p.teaching_styles, '{}'::text[]),
    n.name,
    n.path::text,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'media', sc.media_url,
          'kind', sc.media_kind::text,
          'thumb', sc.thumbnail_url,
          'skill', sn.name,
          'caption', sc.caption
        )
        order by sc.created_at
      )
      from public.skill_showcases sc
      left join public.skill_nodes sn on sn.id = sc.skill_id
      where sc.user_id = us.user_id
    ), '[]'::jsonb)
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  where (p_node::extensions.ltree @> n.path)
    and n.kind = 'skill'
    and us.kind = p_kind
    and n.status = 'approved'
    and p.has_completed_onboarding
    and public.side_ready(us.user_id, p_kind)
    and (auth.uid() is null or us.user_id <> auth.uid())
    and not exists (
      select 1
      from public.blocks b
      where auth.uid() is not null
        and ((b.blocker_id = auth.uid() and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = auth.uid()))
    )
    and not exists (
      select 1
      from public.connections c
      where auth.uid() is not null
        and c.status in ('pending', 'accepted') and c.unmatched_at is null
        and ((c.requester_id = auth.uid() and c.recipient_id = us.user_id)
          or (c.requester_id = us.user_id and c.recipient_id = auth.uid()))
    )
    and not exists (
      select 1
      from public.reports r
      where auth.uid() is not null
        and ((r.reporter_id = auth.uid() and r.reported_id = us.user_id)
          or (r.reporter_id = us.user_id and r.reported_id = auth.uid()))
    )
  order by us.user_id, n.usage_count desc, n.name
  limit greatest(1, least(coalesce(p_limit, 50), 100));
$function$;
-- ---------------------------------------------------------------------------

create or replace function public.browse_random_users(p_limit integer default 20)
returns table (
  user_id uuid,
  name text,
  role text,
  avatar_url text,
  bio text
)
language sql
security definer
set search_path to 'public'
as $$
  select
    p.id,
    coalesce(p.display_name, ''),
    case
      when p.role = 'learner' and public.side_ready(p.id, 'learn') then 'learner'
      when p.role = 'mentor' and public.side_ready(p.id, 'teach') then 'mentor'
      when p.role = 'both'
        and public.side_ready(p.id, 'learn')
        and public.side_ready(p.id, 'teach') then 'both'
      when p.role = 'both' and public.side_ready(p.id, 'learn') then 'learner'
      when p.role = 'both' and public.side_ready(p.id, 'teach') then 'mentor'
      else p.role::text
    end,
    p.avatar_url,
    p.bio
  from public.profiles p
  where p.has_completed_onboarding
    and p.id <> auth.uid()
    and (
      (p.role = 'learner' and public.side_ready(p.id, 'learn'))
      or (p.role = 'mentor' and public.side_ready(p.id, 'teach'))
      or (p.role = 'both' and (
        public.side_ready(p.id, 'learn')
        or public.side_ready(p.id, 'teach')
      ))
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    )
    and not exists (
      select 1 from public.connections c
      where c.status in ('pending', 'accepted') and c.unmatched_at is null
        and ((c.requester_id = auth.uid() and c.recipient_id = p.id)
          or (c.requester_id = p.id and c.recipient_id = auth.uid()))
    )
    and not exists (
      select 1 from public.reports r
      where (r.reporter_id = auth.uid() and r.reported_id = p.id)
         or (r.reporter_id = p.id and r.reported_id = auth.uid())
    )
  order by random()
  limit greatest(1, least(coalesce(p_limit, 20), 200));
$$;
-- ---------------------------------------------------------------------------

create or replace function public.browse_domain_counts(
  p_kind public.skill_kind default 'teach'
)
returns table (root_path text, total integer, fresh integer, newcomers integer)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
with me as (
  select auth.uid() as uid
),
eligible as (
  select distinct us.user_id, root.path::text as root_path, p.created_at
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.skill_nodes root
    on root.kind = 'category'
   and root.depth = 1
   and root.path::text = split_part(n.path::text, '.', 1)
  join public.profiles p on p.id = us.user_id
  cross join me
  where us.kind = p_kind
    and n.kind = 'skill'
    and n.status = 'approved'
    and p.has_completed_onboarding
    and public.side_ready(us.user_id, p_kind)
    and (me.uid is null or us.user_id <> me.uid)
    and not exists (
      select 1
      from public.blocks b
      where me.uid is not null
        and ((b.blocker_id = me.uid and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = me.uid))
    )
    and not exists (
      select 1
      from public.reports r
      where me.uid is not null
        and ((r.reporter_id = me.uid and r.reported_id = us.user_id)
          or (r.reporter_id = us.user_id and r.reported_id = me.uid))
    )
),
counts as (
  select
    e.root_path,
    count(*)::int as total,
    count(*) filter (
      where me.uid is null
         or not exists (
           select 1
           from public.connections c
           where c.status in ('pending', 'accepted') and c.unmatched_at is null
             and ((c.requester_id = me.uid and c.recipient_id = e.user_id)
               or (c.requester_id = e.user_id and c.recipient_id = me.uid))
         )
    )::int as fresh,
    count(*) filter (
      where e.created_at >= now() - interval '7 days'
    )::int as newcomers
  from eligible e
  cross join me
  group by e.root_path
)
select
  root.path::text,
  coalesce(c.total, 0),
  coalesce(c.fresh, 0),
  coalesce(c.newcomers, 0)
from public.skill_nodes root
left join counts c on c.root_path = root.path::text
where root.kind = 'category'
  and root.depth = 1
order by root.path;
$function$;
-- ---------------------------------------------------------------------------

create or replace function public.browse_people_counts(
  p_node text,
  p_kind public.skill_kind default 'teach'
)
returns table (total integer, fresh integer, newcomers integer)
language sql
stable
security definer
set search_path = 'public', 'extensions'
as $function$
with me as (
  select auth.uid() as uid
),
eligible as (
  select distinct us.user_id, p.created_at
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join public.profiles p on p.id = us.user_id
  cross join me
  where (p_node::extensions.ltree @> n.path)
    and n.kind = 'skill'
    and n.status = 'approved'
    and us.kind = p_kind
    and p.has_completed_onboarding
    and public.side_ready(us.user_id, p_kind)
    and (me.uid is null or us.user_id <> me.uid)
    and not exists (
      select 1
      from public.blocks b
      where me.uid is not null
        and ((b.blocker_id = me.uid and b.blocked_id = us.user_id)
          or (b.blocker_id = us.user_id and b.blocked_id = me.uid))
    )
    and not exists (
      select 1
      from public.reports r
      where me.uid is not null
        and ((r.reporter_id = me.uid and r.reported_id = us.user_id)
          or (r.reporter_id = us.user_id and r.reported_id = me.uid))
    )
)
select
  count(*)::int as total,
  count(*) filter (
    where me.uid is null
       or not exists (
         select 1
         from public.connections c
         where c.status in ('pending', 'accepted') and c.unmatched_at is null
           and ((c.requester_id = me.uid and c.recipient_id = e.user_id)
             or (c.requester_id = e.user_id and c.recipient_id = me.uid))
       )
  )::int as fresh,
  count(*) filter (
    where e.created_at >= now() - interval '7 days'
  )::int as newcomers
from eligible e
cross join me;
$function$;
-- ---------------------------------------------------------------------------

create or replace function public.match_candidates(
  p_user uuid,
  p_target embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real
)
returns table(candidate_id uuid, bi_score real)
language sql
stable
security definer
set search_path to 'public'
as $$
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
connected as (
  select case when c.requester_id = p_user then c.recipient_id else c.requester_id end as uid
  from public.connections c
  where c.status in ('pending', 'accepted') and c.unmatched_at is null
    and (c.requester_id = p_user or c.recipient_id = p_user)
),
reported as (
  select case when r.reporter_id = p_user then r.reported_id else r.reporter_id end as uid
  from public.reports r
  where r.reporter_id = p_user or r.reported_id = p_user
),
model as (
  select coalesce(
    (select value #>> '{}' from public.pipeline_config where key = 'embedding_model'),
    'nvidia/nemotron-3.5-embed-1b'
  ) as name
),
s_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'skills'::public.embed_field_group
    and model_name = (select name from model)
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query' and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
    and model_name = (select name from model)
),
s_sc as (
  select e.user_id, (1 - extensions.cosine_distance(s_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join s_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'skills'::public.embed_field_group
    and e.model_name = (select name from model)
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
    and not exists (select 1 from connected cn where cn.uid = e.user_id)
    and not exists (select 1 from reported rp where rp.uid = e.user_id)
),
c_sc as (
  select e.user_id, (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target and e.input_type = 'passage' and e.field_group = 'context'::public.embed_field_group
    and e.model_name = (select name from model)
    and e.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = e.user_id)
    and not exists (select 1 from connected cn where cn.uid = e.user_id)
    and not exists (select 1 from reported rp where rp.uid = e.user_id)
),
fallback as (
  select distinct us.user_id
  from public.user_skills us
  cross join target_kind tk
  join public.skill_nodes n
    on n.id = us.skill_id
   and n.kind = 'skill'
   and n.status = 'approved'
  join public.profiles pf on pf.id = us.user_id and pf.has_completed_onboarding
  where us.kind = tk.k
    and us.user_id <> p_user
    and public.side_ready(us.user_id, tk.k)
    and not exists (select 1 from blocked b where b.uid = us.user_id)
    and not exists (select 1 from connected cn where cn.uid = us.user_id)
    and not exists (select 1 from reported rp where rp.uid = us.user_id)
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
  and not exists (select 1 from connected cn where cn.uid = u.user_id)
  and not exists (select 1 from reported rp where rp.uid = u.user_id)
  and public.side_ready(u.user_id, case when p_target = 'mentor' then 'teach'::public.skill_kind else 'learn'::public.skill_kind end)
  and (
    coalesce(auth.role(), '') = 'service_role'
    or p_user = auth.uid()
  )
order by 2 desc
limit p_limit;
$$;
-- ---------------------------------------------------------------------------

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
    and public.side_ready(p_candidate, case when r.as_role = 'mentor' then 'teach'::public.skill_kind else 'learn'::public.skill_kind end);
$$;
-- ---------------------------------------------------------------------------

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
      and public.side_ready(p_candidate, 'teach')
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
      ) and public.side_ready(p_candidate, 'learn')
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
      ) and public.side_ready(e.recipient_id, case when e.as_role = 'mentor' then 'learn'::public.skill_kind else 'teach'::public.skill_kind end)
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
-- ---------------------------------------------------------------------------

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
          and public.side_ready(p.id, 'teach'))
        or (p_as_role = 'learner' and p.role in ('learner','both') and public.side_ready(p.id, 'learn'))
      )
  ) then
    v_status := 'suppressed';
    v_reason := 'candidate_ineligible';
  elsif not exists (
    select 1 from public.profiles r
    where r.id = p_recipient
      and coalesce(r.has_completed_onboarding, false)
      and r.moderation_status = 'active'
      and public.side_ready(r.id, case when p_as_role = 'mentor' then 'learn'::public.skill_kind else 'teach'::public.skill_kind end)
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
-- ---------------------------------------------------------------------------

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

      -- No ready mentor side and no ready learner side means there is no
      -- direction to notify for, even after retries.
      if not public.side_ready(v_job.candidate_id, 'teach')
         and not public.side_ready(v_job.candidate_id, 'learn') then
        update public.possible_match_jobs
        set status = 'skipped',
            locked_at = null,
            last_error = 'profile_not_ready',
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
