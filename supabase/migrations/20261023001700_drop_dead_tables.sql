-- B16: remove the legacy availability table/function and the unused
-- per-user weight override table. Availability is stored on
-- profiles.availability; nothing reads either table anymore.
drop function if exists public.set_availability_slots(jsonb);
drop table if exists public.availability_slots;
drop table if exists public.user_weight_overrides;
