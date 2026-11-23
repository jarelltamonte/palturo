-- Helpers for the optional sandbox stages. PostgREST cannot reach the sandbox
-- schema, so the API reads texts and writes vectors through these definer
-- functions instead of exposing the schema.

create or replace function public.sandbox_profile_texts(
  p_offset integer default 0,
  p_limit integer default 16
)
returns table (
  user_id uuid,
  role text,
  field_group text,
  input_type text,
  source_text text
)
language sql
stable
security definer
set search_path = public, sandbox
as $$
  select pe.user_id, pe.role::text, pe.field_group::text, pe.input_type, pe.source_text
  from sandbox.profile_embeddings pe
  order by pe.user_id, pe.role, pe.field_group, pe.input_type
  offset greatest(0, p_offset)
  limit greatest(1, least(p_limit, 64));
$$;

create or replace function public.sandbox_card_texts(
  p_offset integer default 0,
  p_limit integer default 16
)
returns table (
  card_id uuid,
  input_type text,
  source_text text
)
language sql
stable
security definer
set search_path = public, sandbox
as $$
  select ce.card_id, ce.input_type, ce.source_text
  from sandbox.card_embeddings ce
  order by ce.card_id, ce.input_type
  offset greatest(0, p_offset)
  limit greatest(1, least(p_limit, 64));
$$;

create or replace function public.sandbox_set_profile_embeddings(p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = public, sandbox, extensions
as $$
declare
  v_count integer := 0;
  item jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden';
  end if;
  for item in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    update sandbox.profile_embeddings pe
    set embedding = (
          select array_agg(value::real)::extensions.vector
          from jsonb_array_elements_text(item -> 'embedding') value
        ),
        model_name = item ->> 'model_name',
        updated_at = now()
    where pe.user_id = (item ->> 'user_id')::uuid
      and pe.role = (item ->> 'role')::public.embed_role
      and pe.field_group = (item ->> 'field_group')::public.embed_field_group
      and pe.input_type = item ->> 'input_type';
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.sandbox_set_card_embeddings(p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = public, sandbox, extensions
as $$
declare
  v_count integer := 0;
  item jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden';
  end if;
  for item in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    update sandbox.card_embeddings ce
    set embedding = (
          select array_agg(value::real)::extensions.vector
          from jsonb_array_elements_text(item -> 'embedding') value
        ),
        model_name = item ->> 'model_name',
        updated_at = now()
    where ce.card_id = (item ->> 'card_id')::uuid
      and ce.input_type = item ->> 'input_type';
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.sandbox_profile_texts(integer, integer) from public, anon, authenticated;
revoke all on function public.sandbox_card_texts(integer, integer) from public, anon, authenticated;
revoke all on function public.sandbox_set_profile_embeddings(jsonb) from public, anon, authenticated;
revoke all on function public.sandbox_set_card_embeddings(jsonb) from public, anon, authenticated;

grant execute on function public.sandbox_profile_texts(integer, integer) to service_role;
grant execute on function public.sandbox_card_texts(integer, integer) to service_role;
grant execute on function public.sandbox_set_profile_embeddings(jsonb) to service_role;
grant execute on function public.sandbox_set_card_embeddings(jsonb) to service_role;
