-- PalTuro is an adult-only exchange. Demographics are optional, but when an
-- age is stored it must be between 18 and 120.
--
-- Existing out-of-range values are cleared first so the constraint can be
-- added on a populated database. The production launch wipes the database.

update public.profile_demographics
set age = null
where age is not null
  and (age < 18 or age > 120);

alter table public.profile_demographics
  drop constraint if exists profile_demographics_age_check;

alter table public.profile_demographics
  add constraint profile_demographics_age_check
  check (age is null or (age >= 18 and age <= 120));
