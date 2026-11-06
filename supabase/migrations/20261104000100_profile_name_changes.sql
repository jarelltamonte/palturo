-- Name changes are a sensitive account action: enforce the lifetime limit and
-- the 60-day cooldown in the database, not only in the client.

alter table public.profiles
  add column if not exists name_change_count integer not null default 0,
  add column if not exists name_changed_at timestamptz;

create or replace function public.get_name_change_status()
returns table (
  changes_used integer,
  changes_remaining integer,
  can_change boolean,
  next_change_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    coalesce(p.name_change_count, 0) as changes_used,
    greatest(0, 2 - coalesce(p.name_change_count, 0)) as changes_remaining,
    case
      when coalesce(p.name_change_count, 0) >= 2 then false
      when p.name_changed_at is null then true
      else p.name_changed_at <= now() - interval '60 days'
    end as can_change,
    case
      when coalesce(p.name_change_count, 0) >= 2 then null::timestamptz
      when p.name_changed_at is null then null::timestamptz
      when p.name_changed_at <= now() - interval '60 days' then null::timestamptz
      else p.name_changed_at + interval '60 days'
    end as next_change_at
  from public.profiles p
  where p.id = auth.uid();
$$;

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
  clean_first text := btrim(coalesce(p_first_name, ''));
  clean_last text := btrim(coalesce(p_last_name, ''));
  used integer;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;

  if clean_first = '' then
    raise exception 'First name is required';
  end if;

  if length(clean_first) > 50 or length(clean_last) > 50 then
    raise exception 'Names must be 50 characters or fewer';
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

  -- An unchanged save must not consume a lifetime change or start the cooldown.
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

  return query
  select used + 1,
         greatest(0, 2 - (used + 1)),
         case
           when used + 1 >= 2 then null::timestamptz
           else now() + interval '60 days'
         end;
end;
$$;

revoke all on function public.get_name_change_status() from public, anon;
revoke all on function public.change_profile_name(text, text) from public, anon;
grant execute on function public.get_name_change_status() to authenticated, service_role;
grant execute on function public.change_profile_name(text, text) to authenticated, service_role;

-- Names are now writable only through change_profile_name(). This closes the
-- direct-PATCH bypass and keeps the lifetime/cooldown counts authoritative.
revoke update (first_name, last_name) on public.profiles from authenticated;
