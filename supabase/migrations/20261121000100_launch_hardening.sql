-- Production launch hardening.
--
-- 1. Remove the leftover diagnostics helper from the build environment.
-- 2. Internal trigger/maintenance helpers are not client APIs. PostgREST does
--    not expose functions that return trigger, but revoking EXECUTE removes
--    the dependency on that behaviour.
-- 3. Showcases are readable only while the owner's profile is visible and the
--    pair is not blocked. Writes stay behind set_skill_showcases().

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = '_test_sp'
  loop
    execute format('drop function %s', fn.sig);
  end loop;
end;
$$;

do $$
declare
  fn text;
  helpers text[] := array[
    'cleanup_connection_notifications',
    'cleanup_possible_match_pair',
    'cleanup_possible_match_profile',
    'invalidate_all_match_cache',
    'invalidate_block_match_cache',
    'invalidate_connection_match_cache',
    'invalidate_profile_media_match_cache',
    'invalidate_report_match_cache',
    'invalidate_showcase_match_cache',
    'limit_skill_showcases',
    'possible_match_enqueue_media',
    'possible_match_enqueue_profile',
    'possible_match_enqueue_skill',
    'rate_limit_connection_insert',
    'rate_limit_message_insert',
    'rate_limit_report_insert',
    'sanitize_profile_media',
    'set_onboarding_completed',
    'skill_node_write_guard',
    'sync_account_warning_count',
    'sync_profile_presence',
    'sync_user_skill_categories',
    'user_skill_write_guard',
    'validate_skill_showcase_media'
  ];
begin
  foreach fn in array helpers loop
    if exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = fn
        and p.pronargs = 0
    ) then
      execute format(
        'revoke execute on function public.%I() from public, anon, authenticated',
        fn
      );
      execute format(
        'grant execute on function public.%I() to service_role',
        fn
      );
    end if;
  end loop;
end;
$$;

-- Read policy: owner, or a profile the caller is allowed to see.
alter table public.skill_showcases enable row level security;

drop policy if exists showcase_read on public.skill_showcases;
create policy showcase_read on public.skill_showcases
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.profile_visible(user_id)
  );

-- Writes go through set_skill_showcases() only.
revoke insert, update, delete on public.skill_showcases
  from public, anon, authenticated;
