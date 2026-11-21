-- Synthetic profile embeddings for the local fixtures.
--
-- No provider key is available offline, so the real passages cannot be
-- embedded. These vectors are deterministic: one dimension per approved skill,
-- so users who share a skill have cosine 1.0 and unrelated skills have 0.0.
-- Context vectors are shared, which mirrors "similar availability/language".
--
-- This file is only for local integration testing.

begin;

delete from public.profile_embeddings
where user_id in (select id from auth.users where email like '%@example.test');

with path_idx as (
  select path::text as path, row_number() over (order by path) as idx
  from public.skill_nodes
  where kind = 'skill' and status = 'approved'
),
user_paths as (
  select us.user_id,
         us.kind,
         array_agg(pi.idx) as idxs
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  join path_idx pi on pi.path = n.path::text
  join auth.users u on u.id = us.user_id
  where u.email like '%@example.test'
  group by us.user_id, us.kind
),
skill_vectors as (
  select up.user_id,
         case when up.kind = 'learn'
              then 'learner'::public.embed_role
              else 'mentor'::public.embed_role end as role,
         (
           select array_agg(
                    case when i = any (up.idxs) then 0.5 else 0.0 end
                    order by i
                  )
           from generate_series(1, 1024) i
         )::extensions.vector(1024) as embedding
  from user_paths up
)
insert into public.profile_embeddings (
  user_id, role, field_group, source_text, source_hash, model_name, embedding, input_type
)
select sv.user_id,
       sv.role,
       'skills'::public.embed_field_group,
       'synthetic card skills',
       md5(sv.user_id::text || sv.role::text || 'skills'),
       'nvidia/nemotron-3.5-embed-1b',
       sv.embedding,
       it.input_type
from skill_vectors sv
cross join (values ('passage'), ('query')) as it(input_type);

with ctx as (
  select (
    select array_agg(case when i = 1024 then 1.0 else 0.0 end order by i)
    from generate_series(1, 1024) i
  )::extensions.vector(1024) as embedding
)
insert into public.profile_embeddings (
  user_id, role, field_group, source_text, source_hash, model_name, embedding, input_type
)
select u.id,
       r.role,
       'context'::public.embed_field_group,
       'synthetic context',
       md5(u.id::text || r.role::text || 'context'),
       'nvidia/nemotron-3.5-embed-1b',
       ctx.embedding,
       it.input_type
from auth.users u
cross join (values ('learner'::public.embed_role), ('mentor'::public.embed_role)) as r(role)
cross join (values ('passage'), ('query')) as it(input_type)
cross join ctx
where u.email like '%@example.test';

commit;

select count(*) as synthetic_embeddings
from public.profile_embeddings pe
join auth.users u on u.id = pe.user_id
where u.email like '%@example.test';
