-- The classifier already decides whether a custom skill is valid and safe.
-- A newly created node used to be left `pending`, which made it invisible to
-- discovery and passages even though the profile save succeeded. There was no
-- approval worker or admin UI, so accepted skills never became usable.
--
-- Accepted nodes now function immediately (`approved` + visible) while
-- `auto_approved` records that the classifier, not a human, accepted them. The
-- future admin panel can filter on this flag, review the linked moderation log,
-- and merge, retire, or reject nodes manually.
alter table public.skill_nodes
  add column if not exists auto_approved boolean not null default false;

create index if not exists skill_nodes_auto_approved_idx
  on public.skill_nodes (created_at desc)
  where auto_approved;

-- Promote submissions the classifier already accepted before this migration.
-- The classifier is the only writer of user-submitted nodes.
update public.skill_nodes
set status = 'approved',
    is_visible = true,
    auto_approved = true,
    updated_at = now()
where status = 'pending'
  and origin = 'user_submitted';

-- Keep a direct link from the moderation log to the node it accepted so the
-- admin panel can show the automod verdict and confidence per skill.
alter table public.skill_moderation_log
  add column if not exists skill_node_id uuid
  references public.skill_nodes(id) on delete set null;

create index if not exists skill_moderation_log_node_idx
  on public.skill_moderation_log (skill_node_id)
  where skill_node_id is not null;
