-- Per-user write rate limits. The limiter already existed for Edge Functions;
-- these triggers apply it to the hot write paths so clients cannot mass-send
-- requests, messages, or reports directly through PostgREST.
create or replace function public.rate_limit_connection_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pending'
     and auth.uid() is not null
     and not public.consume_rate_limit(
       auth.uid(), 'send_connection_request', 20, 86400
     ) then
    raise exception 'Too many connection requests today';
  end if;
  return new;
end;
$$;

drop trigger if exists rate_limit_connection_insert on public.connections;
create trigger rate_limit_connection_insert
  before insert on public.connections
  for each row execute function public.rate_limit_connection_insert();

create or replace function public.rate_limit_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.consume_rate_limit(
       auth.uid(), 'send_message', 60, 60
     ) then
    raise exception 'Too many messages. Please wait a moment';
  end if;
  return new;
end;
$$;

drop trigger if exists rate_limit_message_insert on public.messages;
create trigger rate_limit_message_insert
  before insert on public.messages
  for each row execute function public.rate_limit_message_insert();

create or replace function public.rate_limit_report_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and not public.consume_rate_limit(
       auth.uid(), 'report_user', 10, 86400
     ) then
    raise exception 'Too many reports today';
  end if;
  return new;
end;
$$;

drop trigger if exists rate_limit_report_insert on public.reports;
create trigger rate_limit_report_insert
  before insert on public.reports
  for each row execute function public.rate_limit_report_insert();

-- Align the wrapper with the trigger's two-teach-skill cap so the client gets
-- a clean validation message before the row trigger fires.
create or replace function public.save_user_skills(
  p_learning jsonb default null,
  p_teaching jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_result jsonb;
  v_uid uuid := auth.uid();
  v_kind public.skill_kind;
  v_input jsonb;
  v_rec jsonb;
  v_node uuid;
  v_focus uuid;
begin
  if p_teaching is not null
     and jsonb_typeof(p_teaching) = 'array'
     and jsonb_array_length(p_teaching) > 2 then
    raise exception 'Skill cap reached: maximum 2 skills of kind "teach"';
  end if;

  v_result := public.save_user_skills_impl(p_learning, p_teaching);

  if v_uid is null then
    return v_result;
  end if;

  for v_kind, v_input in
    select 'learn'::public.skill_kind, p_learning
    union all
    select 'teach'::public.skill_kind, p_teaching
  loop
    if v_input is null or jsonb_typeof(v_input) <> 'array' then
      continue;
    end if;

    for v_rec in select value from jsonb_array_elements(v_input) loop
      v_focus := public.resolve_skill_focus(v_rec ->> 'name');
      if v_focus is null then
        continue;
      end if;
      v_node := public.resolve_skill_node(v_rec ->> 'name');
      if v_node is null then
        continue;
      end if;

      if not exists (
        select 1
        from public.skill_nodes f
        join public.skill_nodes s on s.id = v_node
        where f.id = v_focus and f.path <@ s.path
      ) then
        continue;
      end if;

      update public.user_skills
      set focus_skill_id = v_focus,
          updated_at = now()
      where user_id = v_uid and skill_id = v_node and kind = v_kind;
    end loop;
  end loop;

  return v_result;
end;
$$;

revoke all on function public.save_user_skills(jsonb, jsonb) from public, anon;
grant execute on function public.save_user_skills(jsonb, jsonb)
  to authenticated, service_role;
