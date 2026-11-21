-- Heuristic note preapproval.
--
-- A note that passes the deterministic prefilter publishes immediately so
-- onboarding is not blocked on the inference worker. The queue still receives
-- the note (tagged `heuristic`) so the worker reviews it asynchronously and can
-- overturn the decision with a notification when it disagrees.

alter table public.user_skills
  drop constraint if exists user_skills_note_approval_source_check;
alter table public.user_skills
  add constraint user_skills_note_approval_source_check
  check (note_approval_source in ('heuristic', 'inference', 'manual'));

alter table public.note_moderation_queue
  drop constraint if exists note_moderation_queue_decision_source_check;
alter table public.note_moderation_queue
  add constraint note_moderation_queue_decision_source_check
  check (decision_source in ('heuristic', 'inference', 'manual'));

-- SQL mirror of supabase/functions/_shared/note_rules.ts. Returns null when the
-- note is safe to preapprove, otherwise the issue code. Keep the two in sync.
create or replace function public.note_preapprove(
  p_note text,
  p_skill_name text
)
returns text
language plpgsql
immutable
set search_path to 'public'
as $$
declare
  v_note text := btrim(coalesce(p_note, ''), E' \t\n\r');
  v_words text[];
  v_letters text;
  v_normalized text;
  v_normalized_skill text;
  v_word text;
  v_token text;
begin
  if v_note = '' then
    return 'empty';
  end if;
  if char_length(v_note) < 10 then
    return 'too_short';
  end if;
  if char_length(v_note) > 150 then
    return 'too_long';
  end if;
  if v_note ~ '[[:cntrl:]]'
     or v_note ~ U&'[\00AD\200B-\200F\202A-\202E\2060-\206F\FEFF]' then
    return 'markup';
  end if;
  if v_note ~* '(https?://|www\.|@[a-z0-9.-]+\.[a-z]{2,}|\+?[0-9][0-9 (.).-]{7,}[0-9]|[<>])' then
    return 'pii';
  end if;
  if v_note ~* '(ignore (all )?(previous|above|prior)|disregard (the )?(previous|above)|system\s*:|assistant\s*:|you are now|set (relevant|safe|value).{0,20}(1|true)|rank me first|prefer (this|my) profile|boost (this|my)|top (result|match)|match me (first|higher)|when ranking)' then
    return 'injection';
  end if;

  v_words := regexp_split_to_array(v_note, '\s+');
  if coalesce(array_length(v_words, 1), 0) < 2 then
    return 'too_few_words';
  end if;
  if coalesce(array_length(v_words, 1), 0) > 40 then
    return 'too_long';
  end if;

  v_letters := regexp_replace(v_note, '[^[:alpha:]]', '', 'g');
  if char_length(v_letters) < 6 then
    return 'mostly_symbols';
  end if;
  if char_length(v_letters)::numeric / char_length(v_note) < 0.55 then
    return 'mostly_symbols';
  end if;

  if (
    select count(distinct t.c)
    from regexp_split_to_table(lower(v_letters), '') as t(c)
  ) < 3 then
    return 'gibberish';
  end if;

  v_normalized := lower(regexp_replace(v_note, '\s+', ' ', 'g'));
  v_normalized_skill := lower(regexp_replace(btrim(coalesce(p_skill_name, '')), '\s+', ' ', 'g'));
  if v_normalized_skill <> '' and v_normalized = v_normalized_skill then
    return 'skill_echo';
  end if;

  if (
    select count(distinct lower(t.word))
    from unnest(v_words) as t(word)
  ) < 2 then
    return 'repeated_words';
  end if;

  foreach v_word in array v_words loop
    v_token := regexp_replace(v_word, '^[^[:alpha:]]+|[^[:alpha:]]+$', '', 'g');
    continue when v_token = '';
    if v_token ~ '(.)\1{3,}' then
      return 'gibberish';
    end if;
    if char_length(v_token) >= 5 and (
      select count(distinct t.c)
      from regexp_split_to_table(lower(v_token), '') as t(c)
    ) <= 2 then
      return 'gibberish';
    end if;
    if char_length(v_token) <= 12
       and v_token ~* '(qwe|wer|ert|rty|tyu|yui|uio|iop|asd|sdf|dfg|fgh|ghj|hjk|jkl|zxc|xcv|cvb|vbn|bnm)' then
      return 'gibberish';
    end if;
    if v_token ~* '[bcdfghjklmnpqrstvwxz]{6,}' then
      return 'gibberish';
    end if;
  end loop;

  return null;
end;
$$;

-- Runs after trg_user_skills_note_approval (alphabetical order), which clears
-- the old approval when the note text changes. Only a newly written note is
-- eligible, so an inference rejection of the same text is never re-approved.
create or replace function public.preapprove_skill_note()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_skill_name text;
begin
  if new.note is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.note is not distinct from old.note then
    return new;
  end if;

  select n.name into v_skill_name
  from public.skill_nodes n
  where n.id = new.skill_id;

  if public.note_preapprove(new.note, coalesce(v_skill_name, '')) is null then
    new.note_approved := true;
    new.note_approval_source := 'heuristic';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_user_skills_note_preapprove on public.user_skills;
create trigger trg_user_skills_note_preapprove
  before insert or update of note on public.user_skills
  for each row
  execute function public.preapprove_skill_note();

-- Queue heuristic approvals for the asynchronous inference review. The queue
-- row carries the heuristic provenance so the admin table can badge it.
create or replace function public.enqueue_preapproved_note()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_name text;
begin
  if new.note is null or btrim(new.note) = '' then
    return null;
  end if;
  if tg_op = 'UPDATE' and new.note is not distinct from old.note then
    return null;
  end if;
  if not coalesce(new.note_approved, false)
     or new.note_approval_source is distinct from 'heuristic' then
    return null;
  end if;

  select n.name into v_name
  from public.skill_nodes n
  where n.id = new.skill_id;
  if v_name is null then
    return null;
  end if;

  insert into public.note_moderation_queue (
    user_id, kind, name, skill_id, note, note_hash, status,
    decision_source, attempts
  ) values (
    new.user_id, new.kind, v_name, new.skill_id, new.note, md5(new.note),
    'pending', 'heuristic', 0
  )
  on conflict (user_id, kind, name) do update
    set skill_id = excluded.skill_id,
        note = excluded.note,
        note_hash = excluded.note_hash,
        status = 'pending',
        decision_source = 'heuristic',
        attempts = 0,
        last_error = null,
        updated_at = now();

  return null;
end;
$$;

drop trigger if exists trg_user_skills_note_enqueue on public.user_skills;
create trigger trg_user_skills_note_enqueue
  after insert or update of note on public.user_skills
  for each row
  execute function public.enqueue_preapproved_note();

-- A queue row can outlive the note that earned its provenance: editing a
-- heuristic-preapproved note into one that fails the prefilter updates the
-- pending row without clearing decision_source. Drop a heuristic tag that no
-- longer matches a currently approved heuristic note.
create or replace function public.sync_note_decision_source()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.status = 'pending'
     and new.decision_source = 'heuristic'
     and not exists (
       select 1
       from public.user_skills us
       where us.user_id = new.user_id
         and us.kind = new.kind
         and us.skill_id = new.skill_id
         and us.note = new.note
         and us.note_approved
         and us.note_approval_source = 'heuristic'
     ) then
    new.decision_source := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_note_queue_decision_source
  on public.note_moderation_queue;
create trigger trg_note_queue_decision_source
  before insert or update on public.note_moderation_queue
  for each row
  execute function public.sync_note_decision_source();

-- Allow the rejection notice. Existing kinds are preserved.
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in (
    'connection_request',
    'request_accepted',
    'request_declined',
    'feedback_ready',
    'skill_moderation',
    'possible_match',
    'account_warning',
    'note_rejected'
  ));

-- The observed false rejections were short but legitimate personal notes.
-- Lower the relevance/value floors unless an operator has already tuned them
-- away from the previous default.
update public.pipeline_config
set value = to_jsonb(0.5),
    updated_at = now()
where key = 'note_min_relevance'
  and value = to_jsonb(0.6);

update public.pipeline_config
set value = to_jsonb(0.4),
    updated_at = now()
where key = 'note_min_value'
  and value = to_jsonb(0.6);

-- A database that never had these keys falls back to the worker's 0.6 code
-- defaults. Seed them so the tuned floors actually apply.
insert into public.pipeline_config (key, value, description, config_version)
values
  ('note_min_relevance', to_jsonb(0.5),
   'Minimum model relevance for a skill note', 1),
  ('note_min_value', to_jsonb(0.4),
   'Minimum model value for a skill note', 1)
on conflict (key) do nothing;

revoke all on function public.note_preapprove(text, text)
  from public, anon, authenticated;
revoke all on function public.preapprove_skill_note()
  from public, anon, authenticated;
revoke all on function public.enqueue_preapproved_note()
  from public, anon, authenticated;
revoke all on function public.sync_note_decision_source()
  from public, anon, authenticated;
