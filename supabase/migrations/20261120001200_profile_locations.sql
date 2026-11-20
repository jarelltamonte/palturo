-- Coarse location from the request IP, captured by the Cloudflare Worker.
-- Only country/region/city/timezone are stored; the IP is never persisted.

create table if not exists public.profile_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  country_code text not null check (char_length(country_code) = 2),
  region text,
  region_code text,
  city text,
  timezone text,
  updated_at timestamptz not null default now()
);

alter table public.profile_locations enable row level security;
revoke all on public.profile_locations from public, anon, authenticated;

create or replace function public.save_my_location(
  p_country_code text,
  p_region text,
  p_region_code text,
  p_city text,
  p_timezone text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_country text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_country := upper(btrim(coalesce(p_country_code, '')));
  if char_length(v_country) <> 2 then
    return;
  end if;

  insert into public.profile_locations (
    user_id, country_code, region, region_code, city, timezone, updated_at
  )
  values (
    v_uid,
    v_country,
    nullif(left(btrim(coalesce(p_region, '')), 120), ''),
    nullif(left(btrim(coalesce(p_region_code, '')), 12), ''),
    nullif(left(btrim(coalesce(p_city, '')), 120), ''),
    nullif(left(btrim(coalesce(p_timezone, '')), 80), ''),
    now()
  )
  on conflict (user_id) do update
  set country_code = excluded.country_code,
      region = excluded.region,
      region_code = excluded.region_code,
      city = excluded.city,
      timezone = excluded.timezone,
      updated_at = now();
end;
$$;

revoke all on function public.save_my_location(text, text, text, text, text)
  from public, anon;
grant execute on function public.save_my_location(text, text, text, text, text)
  to authenticated;

-- Maps a Philippine region (ISO code or name) to Luzon / Visayas / Mindanao.
create or replace function public.ph_island_group(
  p_region_code text,
  p_region text
)
returns text
language plpgsql
immutable
as $$
declare
  v_code text := right(upper(coalesce(p_region_code, '')), 2);
  v_region text := lower(coalesce(p_region, ''));
begin
  if v_code in ('00', '01', '02', '03', '05', '15', '40', '41') then
    return 'Luzon';
  end if;
  if v_code in ('06', '07', '08') then
    return 'Visayas';
  end if;
  if v_code in ('09', '10', '11', '12', '13', '14') then
    return 'Mindanao';
  end if;

  if v_region <> '' then
    if v_region similar to '%(metro manila|national capital|ilocos|cagayan|central luzon|calabarzon|mimaropa|bicol|cordillera|bataan|batangas|bulacan|cavite|laguna|quezon|pampanga|pangasinan|nueva ecija|tarlac|zambales|aurora|isabela|la union|benguet|abra|apayao|ifugao|kalinga|mountain province|albay|camarines|sorsogon|masbate|romblon|marinduque|mindoro|palawan)%' then
      return 'Luzon';
    end if;
    if v_region similar to '%(western visayas|central visayas|eastern visayas|aklan|antique|capiz|guimaras|iloilo|negros|bohol|cebu|siquijor|biliran|leyte|samar)%' then
      return 'Visayas';
    end if;
    if v_region similar to '%(zamboanga|northern mindanao|davao|soccsksargen|caraga|barmm|agusan|surigao|misamis|bukidnon|lanao|maguindanao|sulu|basilan|tawi|cotabato|sultan kudarat|sarangani|compostela)%' then
      return 'Mindanao';
    end if;
  end if;

  return 'Unknown';
end;
$$;

revoke all on function public.ph_island_group(text, text)
  from public, anon, authenticated;
