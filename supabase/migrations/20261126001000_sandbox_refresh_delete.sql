-- TRUNCATE takes ACCESS EXCLUSIVE and fails when the caller's statement already
-- holds a read lock on a sandbox table (and would block a concurrent sandbox
-- run). DELETE keeps the refresh safe inside one request.

create or replace function public.sandbox_refresh(p_max_age_seconds integer default 600)
returns jsonb
language plpgsql
security definer
set search_path = public, sandbox
as $$
declare
  v_last timestamptz;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden';
  end if;

  select max(snapshotted_at) into v_last from sandbox.snapshot;
  if v_last is not null
     and now() - v_last < make_interval(secs => greatest(0, p_max_age_seconds)) then
    return jsonb_build_object('refreshed', false, 'snapshot_at', v_last);
  end if;

  delete from sandbox.profiles;
  delete from sandbox.skill_nodes;
  delete from sandbox.user_skills;
  delete from sandbox.profile_embeddings;
  delete from sandbox.card_embeddings;

  insert into sandbox.profiles select * from public.profiles;
  insert into sandbox.skill_nodes select * from public.skill_nodes;
  insert into sandbox.user_skills select * from public.user_skills;
  insert into sandbox.profile_embeddings select * from public.profile_embeddings;
  insert into sandbox.card_embeddings select * from public.card_embeddings;
  insert into sandbox.snapshot default values;

  return jsonb_build_object('refreshed', true, 'snapshot_at', now());
end;
$$;

revoke all on function public.sandbox_refresh(integer) from public, anon, authenticated;
grant execute on function public.sandbox_refresh(integer) to service_role;
