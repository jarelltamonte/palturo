-- Batch remove the tagged production mocks.
--
-- Tag = email mock%@palturo.dev AND auth metadata mock=true.
-- Run only through remove_mock_accounts.ps1 (it asks for -Confirm and prints
-- the count first), or apply this file manually with the Management API.
--
-- Public rows cascade from profiles. The few NO ACTION references are cleared
-- explicitly first so the profile delete cannot fail.

begin;

create temp table _mock_ids on commit drop as
select id
from auth.users
where email like 'mock%@palturo.dev'
  and coalesce((raw_user_meta_data ->> 'mock')::boolean, false);

delete from public.skill_moderation_log
where user_id in (select id from _mock_ids);

delete from public.client_errors
where user_id in (select id from _mock_ids);

delete from public.reports
where reporter_id in (select id from _mock_ids)
   or reported_id in (select id from _mock_ids);

-- Notifications can outlive the candidate: remove both mock recipients and
-- notifications whose payload points at a mock candidate.
delete from public.notifications n
using _mock_ids m
where n.user_id = m.id
   or ((n.payload ? 'candidate_id') and (n.payload ->> 'candidate_id')::uuid = m.id);

delete from public.profiles
where id in (select id from _mock_ids);

delete from auth.users
where id in (select id from _mock_ids);

delete from public.match_cache;
delete from public.match_cache_v2;

commit;
