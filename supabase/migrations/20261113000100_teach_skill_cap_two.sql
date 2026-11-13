-- Enforce the paper's asymmetric skill cap: 2 skills to teach, 3 to learn.
--
-- Existing mock/persona rows created under the earlier symmetric 3/3 rule are
-- trimmed to the two earliest teaching placements before the new trigger limit
-- takes effect.
with ranked as (
  select
    id,
    row_number() over (partition by user_id order by created_at, id) as rn
  from public.user_skills
  where kind = 'teach'
)
delete from public.user_skills us
using ranked r
where us.id = r.id
  and r.rn > 2;

create or replace function public.enforce_skill_caps()
returns trigger
language plpgsql
as $$
declare
  n int;
  v_limit int;
begin
  if new.kind = 'secondary' then
    return new;
  end if;

  v_limit := case when new.kind = 'teach' then 2 else 3 end;

  select count(*) into n
  from public.user_skills
  where user_id = new.user_id
    and kind = new.kind
    and id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

  if n >= v_limit then
    raise exception 'Skill cap reached: maximum % skills of kind "%"', v_limit, new.kind;
  end if;

  return new;
end
$$;
