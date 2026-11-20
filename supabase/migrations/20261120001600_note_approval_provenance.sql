-- Note approval provenance.
--
-- Inference-approved notes behave like auto-approved skills: they publish
-- immediately, but carry a source tag so an admin can review and override them
-- later. Admin decisions mark the note as manual.

alter table public.user_skills
  add column if not exists note_approval_source text
  check (note_approval_source in ('inference', 'manual'));

alter table public.note_moderation_queue
  add column if not exists decision_source text
  check (decision_source in ('inference', 'manual'));

-- Everything previously approved came from the worker. Rejections did not
-- publish anything, so only approved rows need a provenance tag.
update public.user_skills
set note_approval_source = 'inference'
where note_approved
  and note_approval_source is null;

update public.note_moderation_queue
set decision_source = 'inference'
where status in ('approved', 'rejected')
  and decision_source is null;

create index if not exists note_queue_decision_source_idx
  on public.note_moderation_queue (decision_source);

-- Any edited note must be re-reviewed. The worker's approval update keeps the
-- note text unchanged, so this does not clear its own verdict.
create or replace function public.reset_note_approval()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if tg_op = 'UPDATE' and new.note is distinct from old.note then
    new.note_approved := false;
    new.note_approval_source := null;
  end if;
  if not coalesce(new.note_approved, false) then
    new.note_approval_source := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_user_skills_note_approval on public.user_skills;
create trigger trg_user_skills_note_approval
  before insert or update on public.user_skills
  for each row
  execute function public.reset_note_approval();

revoke all on function public.reset_note_approval()
  from public, anon, authenticated;
