-- Deterministic display-name policy.
--
-- Names never use inference. The same rules run in the Flutter client and here,
-- so a direct API write cannot bypass them. The generated display_name column
-- continues to concatenate the validated first/last values.

create table if not exists public.name_blocklist (
  term text primary key,
  kind text not null check (kind in ('placeholder', 'profanity', 'phrase'))
);

revoke all on public.name_blocklist from public, anon, authenticated;

insert into public.name_blocklist (term, kind) values
  ('test','placeholder'), ('testing','placeholder'), ('tester','placeholder'),
  ('user','placeholder'), ('username','placeholder'), ('admin','placeholder'),
  ('administrator','placeholder'), ('asdf','placeholder'),
  ('asdfgh','placeholder'), ('qwerty','placeholder'),
  ('qwertyuiop','placeholder'), ('name','placeholder'),
  ('firstname','placeholder'), ('lastname','placeholder'),
  ('anonymous','placeholder'), ('null','placeholder'), ('none','placeholder'),
  ('xxx','placeholder'), ('abc','placeholder'), ('abcdef','placeholder'),
  ('sample','placeholder'), ('demo','placeholder'), ('guest','placeholder'),
  ('temp','placeholder'), ('default','placeholder'), ('unknown','placeholder'),
  ('palturo','placeholder'), ('support','placeholder'), ('official','placeholder'),
  ('fuck','profanity'), ('fucked','profanity'), ('fucker','profanity'),
  ('fuckers','profanity'), ('fucking','profanity'), ('shit','profanity'),
  ('shitty','profanity'), ('bullshit','profanity'), ('bitch','profanity'),
  ('bitches','profanity'), ('cunt','profanity'), ('asshole','profanity'),
  ('assholes','profanity'), ('bastard','profanity'), ('whore','profanity'),
  ('slut','profanity'), ('faggot','profanity'), ('fag','profanity'),
  ('nigger','profanity'), ('nigga','profanity'), ('retard','profanity'),
  ('retarded','profanity'), ('rape','profanity'), ('rapist','profanity'),
  ('porn','profanity'), ('pussy','profanity'), ('wanker','profanity'),
  ('twat','profanity'), ('douche','profanity'),
  ('puta','profanity'), ('putangina','profanity'),
  ('putanginamo','profanity'), ('tangina','profanity'),
  ('tanginamo','profanity'), ('gago','profanity'), ('gaga','profanity'),
  ('bobo','profanity'), ('ulol','profanity'), ('punyeta','profanity'),
  ('kupal','profanity'), ('tarantado','profanity'), ('pakshet','profanity'),
  ('kingina','profanity'), ('iyot','profanity'), ('kantot','profanity'),
  ('hinayupak','profanity'), ('hayop','profanity'),
  ('putangina','phrase'), ('putanginamo','phrase'), ('tanginamo','phrase'),
  ('anakngputa','phrase'), ('sonofabitch','phrase'),
  ('pieceofshit','phrase'), ('fuckyou','phrase')
on conflict (term) do nothing;

create or replace function public.normalize_display_name(p_name text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select btrim(
    regexp_replace(
      translate(
        translate(
          translate(
            coalesce(p_name, ''),
            E'\u2018\u2019\u201A\u201B\u2032',
            repeat('''', 5)
          ),
          E'\u2010\u2011\u2012\u2013\u2014\u2015\u2212',
          repeat('-', 7)
        ),
        E'\u200B\u200C\u200D\u200E\u200F\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069\uFEFF',
        ''
      ),
      '\s+', ' ', 'g'
    )
  );
$$;

create or replace function public.fold_display_name(p_name text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select translate(
    lower(coalesce(p_name, '')),
    'áàâäãåéèêëíìîïóòôöõúùûüñçýÿÁÀÂÄÃÅÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇÝ',
    'aaaaaaeeeeiiiiooooouuuuncyyaaaaaaeeeeiiiiooooouuuuncyy'
  );
$$;

create or replace function public.validate_display_name_part(
  p_name text,
  p_label text
)
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_clean text := public.normalize_display_name(p_name);
  v_token text;
  v_plain text;
  v_folded text;
  v_distinct integer;
  v_index integer;
  v_char text;
begin
  if v_clean = '' then
    raise exception '% is required.', p_label using errcode = '22023';
  end if;
  if length(v_clean) > 50 then
    raise exception '% cannot exceed 50 characters.', p_label
      using errcode = '22023';
  end if;

  if v_clean ~ '[0-9]' then
    raise exception 'Names cannot contain numbers.' using errcode = '22023';
  end if;

  if v_clean ~ '[^[:alpha:] ''.\-]' then
    raise exception 'Names cannot contain emoji or symbols.'
      using errcode = '22023';
  end if;

  if position('.' in v_clean) > 0 and v_clean !~ '^[^.]*\.$' then
    raise exception 'Names can only use letters, spaces, hyphens, and apostrophes.'
      using errcode = '22023';
  end if;

  if array_length(regexp_split_to_array(v_clean, '\s+'), 1) > 3 then
    raise exception 'Please use at most 3 words per name.'
      using errcode = '22023';
  end if;

  foreach v_token in array regexp_split_to_array(v_clean, '\s+') loop
    v_plain := rtrim(v_token, '.');
    if length(regexp_replace(v_plain, '[^[:alpha:]]', '', 'g')) < 2 then
      raise exception '% must be at least 2 letters.', p_label
        using errcode = '22023';
    end if;

    v_folded := public.fold_display_name(v_plain);

    -- Four identical letters in a row; no backreference support in POSIX
    -- regex, so check each letter explicitly.
    for v_index in 1..26 loop
      v_char := chr(96 + v_index);
      if v_folded ~ (v_char || '{4,}') then
        raise exception 'That does not look like a real name. Please enter your actual name.'
          using errcode = '22023';
      end if;
    end loop;

    if length(v_plain) >= 3 then
      select count(distinct c) into v_distinct
      from unnest(string_to_array(lower(v_plain), null)) as c;
      if v_distinct <= 1 then
        raise exception 'That does not look like a real name. Please enter your actual name.'
          using errcode = '22023';
      end if;
    end if;

    if length(v_plain) >= 5 then
      select count(distinct c) into v_distinct
      from unnest(string_to_array(lower(v_plain), null)) as c;
      if v_distinct <= 2 then
        raise exception 'That does not look like a real name. Please enter your actual name.'
          using errcode = '22023';
      end if;
    end if;

    if lower(v_plain) ~ '(qwe|wer|ert|rty|tyu|yui|uio|iop|asd|sdf|dfg|fgh|ghj|hjk|jkl|zxc|xcv|cvb|vbn|bnm)'
       and length(v_plain) <= 12 then
      raise exception 'That does not look like a real name. Please enter your actual name.'
        using errcode = '22023';
    end if;

    if lower(v_plain) ~ '[bcdfghjklmnpqrstvwxz]{6,}' then
      raise exception 'That does not look like a real name. Please enter your actual name.'
        using errcode = '22023';
    end if;

    if exists (
      select 1 from public.name_blocklist b
      where b.kind = 'placeholder' and b.term = v_folded
    ) then
      raise exception 'Please enter your real name, not a placeholder.'
        using errcode = '22023';
    end if;

    if exists (
      select 1 from public.name_blocklist b
      where b.kind = 'profanity' and b.term = v_folded
    ) then
      raise exception 'This name contains language that is not allowed. Please enter your real name.'
        using errcode = '22023';
    end if;
  end loop;

  if exists (
    select 1 from public.name_blocklist b
    where b.term = replace(replace(replace(public.fold_display_name(v_clean), ' ', ''), '-', ''), '''', '')
  ) then
    raise exception 'This name contains language that is not allowed. Please enter your real name.'
      using errcode = '22023';
  end if;

  return v_clean;
end;
$$;

create or replace function public.enforce_display_name()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  new.first_name := public.validate_display_name_part(new.first_name, 'First name');
  new.last_name := public.validate_display_name_part(new.last_name, 'Last name');
  if lower(new.first_name) = lower(new.last_name) then
    raise exception 'First and last name cannot be the same.'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_display_name on public.profiles;
create trigger trg_profiles_display_name
  before insert or update of first_name, last_name on public.profiles
  for each row
  execute function public.enforce_display_name();

revoke all on function public.normalize_display_name(text) from public, anon, authenticated;
revoke all on function public.fold_display_name(text) from public, anon, authenticated;
revoke all on function public.validate_display_name_part(text, text) from public, anon, authenticated;
revoke all on function public.enforce_display_name() from public, anon, authenticated;

-- Keep the RPC's own checks in step with the trigger and drop stale deck rows so
-- a renamed profile does not keep its old display name in cached matches.
create or replace function public.change_profile_name(
  p_first_name text,
  p_last_name text
)
returns table (
  changes_used integer,
  changes_remaining integer,
  next_change_at timestamptz
)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  me uuid := auth.uid();
  current_profile public.profiles%rowtype;
  clean_first text;
  clean_last text;
  used integer;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;

  clean_first := public.validate_display_name_part(p_first_name, 'First name');
  clean_last := public.validate_display_name_part(p_last_name, 'Last name');
  if lower(clean_first) = lower(clean_last) then
    raise exception 'First and last name cannot be the same.'
      using errcode = '22023';
  end if;

  select * into current_profile
  from public.profiles
  where id = me
  for update;

  if not found then
    raise exception 'Profile not found';
  end if;

  used := coalesce(current_profile.name_change_count, 0);

  if used >= 2 then
    raise exception 'You have used both name changes';
  end if;

  if current_profile.name_changed_at is not null
     and current_profile.name_changed_at > now() - interval '60 days' then
    raise exception 'You can change your name once every 60 days';
  end if;

  if clean_first = coalesce(current_profile.first_name, '')
     and clean_last = coalesce(current_profile.last_name, '') then
    return query
    select used,
           greatest(0, 2 - used),
           case
             when current_profile.name_changed_at is null then null::timestamptz
             when used >= 2 then null::timestamptz
             when current_profile.name_changed_at <= now() - interval '60 days'
               then null::timestamptz
             else current_profile.name_changed_at + interval '60 days'
           end;
    return;
  end if;

  update public.profiles
  set first_name = clean_first,
      last_name = clean_last,
      name_change_count = used + 1,
      name_changed_at = now(),
      updated_at = now()
  where id = me;

  delete from public.match_cache
  where user_id = me or candidate_id = me;

  return query
  select used + 1,
         greatest(0, 2 - (used + 1)),
         case
           when used + 1 >= 2 then null::timestamptz
           else now() + interval '60 days'
         end;
end;
$$;

revoke all on function public.change_profile_name(text, text) from public, anon;
grant execute on function public.change_profile_name(text, text)
  to authenticated, service_role;
