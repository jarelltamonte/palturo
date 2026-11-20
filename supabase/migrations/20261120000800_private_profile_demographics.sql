-- Private demographics used for aggregate analytics only.
--
-- These fields are intentionally NOT on public.profiles: profiles has
-- column-level grants that expose visible profiles to other authenticated
-- users. A separate owner-only table keeps age and gender out of cards,
-- public profile RPCs, matching, and browse queries.

create table if not exists public.profile_demographics (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  age smallint,
  gender text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_demographics_age_check
    check (age is null or (age >= 13 and age <= 120)),
  constraint profile_demographics_gender_check
    check (
      gender is null
      or gender in ('woman','man','nonbinary','prefer_not_to_say')
    )
);

alter table public.profile_demographics enable row level security;

drop policy if exists "Users read their own demographics"
  on public.profile_demographics;
create policy "Users read their own demographics"
  on public.profile_demographics
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert their own demographics"
  on public.profile_demographics;
create policy "Users insert their own demographics"
  on public.profile_demographics
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update their own demographics"
  on public.profile_demographics;
create policy "Users update their own demographics"
  on public.profile_demographics
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete their own demographics"
  on public.profile_demographics;
create policy "Users delete their own demographics"
  on public.profile_demographics
  for delete
  using (auth.uid() = user_id);

revoke all on public.profile_demographics from public, anon;
grant select, insert, update, delete on public.profile_demographics
  to authenticated;
grant all on public.profile_demographics to service_role;

create or replace function public.touch_profile_demographics_updated_at()
returns trigger
language plpgsql
set search_path = 'public'
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profile_demographics_updated_at
  on public.profile_demographics;
create trigger profile_demographics_updated_at
  before update on public.profile_demographics
  for each row execute function public.touch_profile_demographics_updated_at();

-- Aggregate-only analytics. No user ids or free text leave the database.
create or replace function public.admin_demographics()
returns jsonb
language sql
stable
security definer
set search_path = 'public'
as $$
  with ages as (
    select age from public.profile_demographics where age is not null
  ),
  age_buckets as (
    select b.label, b.lo,
      (select count(*)::int from public.profile_demographics d
       where d.age between b.lo and b.hi) as n
    from (values
      ('13-17', 13, 17),
      ('18-24', 18, 24),
      ('25-34', 25, 34),
      ('35-44', 35, 44),
      ('45-54', 45, 54),
      ('55-64', 55, 64),
      ('65+', 65, 120)
    ) as b(label, lo, hi)
  ),
  gender_counts as (
    select coalesce(gender, 'not_set') as gender, count(*)::int as n
    from public.profile_demographics
    group by 1
  )
  select jsonb_build_object(
    'total', (select count(*) from public.profile_demographics),
    'with_age', (select count(*) from public.profile_demographics where age is not null),
    'with_gender', (select count(*) from public.profile_demographics where gender is not null),
    'avg_age', coalesce((select round(avg(age)::numeric, 1) from ages), 0),
    'median_age', coalesce((select round(percentile_cont(0.5) within group (order by age)::numeric, 1) from ages), 0),
    'age_buckets', coalesce((
      select jsonb_agg(jsonb_build_object('bucket', label, 'count', n) order by lo)
      from age_buckets
    ), '[]'::jsonb),
    'gender_counts', coalesce((
      select jsonb_object_agg(gender, n) from gender_counts
    ), '{}'::jsonb)
  );
$$;

revoke all on function public.admin_demographics() from public, anon, authenticated;
grant execute on function public.admin_demographics() to service_role;
