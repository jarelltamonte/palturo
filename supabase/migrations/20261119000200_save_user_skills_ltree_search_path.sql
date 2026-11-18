-- save_user_skills() attaches a focus only when it sits under the resolved
-- skill. That containment test uses the ltree `<@` operator, which lives in
-- the extensions schema, but the function was pinned to `search_path=public`.
-- Widen the search path to match the other ltree-aware functions.
--
-- The value must stay unquoted: `SET search_path TO 'public, extensions'`
-- records one schema literally named "public, extensions" and resolves
-- nothing.
alter function public.save_user_skills(jsonb, jsonb)
  set search_path = public, extensions;
