-- A profile array can pick up a null element when an old save carried one.
-- A null in learning_skills/teaching_skills crashes the typed parser and
-- leaves a blank skill row, so clean the data and stop rebuilding it.

update public.profiles
set teaching_skills = coalesce((
      select array_agg(distinct x.name order by x.name)
      from unnest(coalesce(teaching_skills, '{}'::text[])) x
      where x.name is not null and btrim(x.name) <> ''
    ), '{}'::text[]),
    learning_skills = coalesce((
      select array_agg(distinct x.name order by x.name)
      from unnest(coalesce(learning_skills, '{}'::text[])) x
      where x.name is not null and btrim(x.name) <> ''
    ), '{}'::text[]);

-- Showcase rows whose skill is no longer declared by the owner cannot appear
-- on the card and confuse the editor. Remove the leftovers.
delete from public.skill_showcases s
where s.skill_id is not null
  and not exists (
    select 1 from public.user_skills us
    where us.user_id = s.user_id and us.skill_id = s.skill_id
  );

create or replace function public.rebuild_skill_array(
  p_user uuid,
  p_kind public.skill_kind,
  p_existing text[],
  p_exclude uuid default null
)
returns text[]
language sql
stable
set search_path to 'public'
as $$
  select coalesce(array_agg(distinct x order by x), '{}'::text[])
  from (
    select n.name as x
    from public.user_skills us
    join public.skill_nodes n on n.id = us.skill_id
    where us.user_id = p_user and us.kind = p_kind
    union
    select a.name
    from unnest(coalesce(p_existing, '{}'::text[])) a
    where a.name is not null
      and btrim(a.name) <> ''
      and (p_exclude is null
           or public.resolve_skill_node(a.name) is distinct from p_exclude)
      and (
        public.resolve_skill_node(a.name) is null
        or public.resolve_skill_node(a.name) not in (
          select us.skill_id from public.user_skills us
          where us.user_id = p_user and us.kind = p_kind
        )
      )
  ) q;
$$;
