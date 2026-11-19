-- Moderation actions, skill provenance/moves, audit reverts, and managed backups.

-- ---------------------------------------------------------------------------
-- Reports: decision + action are separate.
-- ---------------------------------------------------------------------------
alter table public.reports
  add column if not exists action_taken text
    check (action_taken in ('pass', 'warn', 'suspend', 'ban')),
  add column if not exists action_by uuid references public.profiles(id) on delete set null,
  add column if not exists action_at timestamp with time zone;

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete set null,
  user_id uuid references public.profiles(id) on delete cascade,
  action text not null check (action in ('pass', 'warn', 'suspend', 'ban')),
  reason text,
  actor_id uuid,
  created_at timestamp with time zone not null default now()
);
create index if not exists moderation_actions_user_idx
  on public.moderation_actions (user_id, created_at desc);
create index if not exists moderation_actions_report_idx
  on public.moderation_actions (report_id);

alter table public.profiles
  add column if not exists warning_count integer not null default 0,
  add column if not exists last_warned_at timestamp with time zone;

-- ---------------------------------------------------------------------------
-- Skill provenance: inference vs manual/seed/import.
-- ---------------------------------------------------------------------------
alter table public.skill_nodes
  add column if not exists approval_source text not null default 'manual'
    check (approval_source in ('inference', 'manual', 'seed', 'import'));

update public.skill_nodes
set approval_source = case
  when auto_approved then 'inference'
  when origin = 'official' then 'seed'
  else 'manual'
end
where approval_source = 'manual'
  and (auto_approved or origin = 'official');

-- Allow the admin move function to update a parent with children after it has
-- performed its own cycle/depth validation.
create or replace function public.skill_node_write_guard()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_parent_kind public.skill_node_kind;
  v_parent_path extensions.ltree;
begin
  if current_setting('palturo.suppress_skill_guard', true) = 'on' then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.name = old.name
     and new.parent_id is not distinct from old.parent_id then
    return new;
  end if;

  if new.parent_id is null then
    if new.kind <> 'category' then
      raise exception 'Only categories can be root nodes';
    end if;
  else
    if new.parent_id = new.id then
      raise exception 'A skill node cannot be its own parent';
    end if;

    select kind, path into v_parent_kind, v_parent_path
    from public.skill_nodes where id = new.parent_id;
    if not found then
      raise exception 'Parent node not found';
    end if;

    if v_parent_kind = 'category' and new.kind not in ('category', 'skill') then
      raise exception 'Categories may only contain categories or skills';
    elsif v_parent_kind = 'skill' and new.kind <> 'focus' then
      raise exception 'Skills may only contain focus nodes';
    elsif v_parent_kind = 'focus' and new.kind <> 'focus' then
      raise exception 'Focus nodes may only contain focus nodes';
    end if;

    if tg_op = 'UPDATE' and v_parent_path <@ old.path then
      raise exception 'A node cannot be moved under its own descendant';
    end if;

    if tg_op = 'UPDATE' and exists (
      select 1 from public.skill_nodes where parent_id = old.id
    ) then
      raise exception 'Move or rename a node with children through move_skill_node()';
    end if;
  end if;

  if new.is_general and new.kind <> 'skill' then
    raise exception 'Only skills can be marked general';
  end if;

  return new;
end;
$$;

create or replace function public.admin_move_skill(
  p_node uuid,
  p_new_parent uuid,
  p_actor uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_before public.skill_nodes%rowtype;
  v_node public.skill_nodes%rowtype;
  v_parent public.skill_nodes%rowtype;
  v_old_parent uuid;
  v_old_path extensions.ltree;
  v_new_depth integer;
  v_new_path extensions.ltree;
  v_max_depth integer;
  v_delta integer;
  v_descendants integer := 0;
begin
  if p_node is null then
    raise exception 'Node is required';
  end if;
  if p_node = p_new_parent then
    raise exception 'A node cannot be moved under itself';
  end if;
  if length(coalesce(trim(p_reason), '')) < 3 then
    raise exception 'A reason of at least 3 characters is required';
  end if;

  select * into v_before from public.skill_nodes where id = p_node for update;
  if not found then
    raise exception 'Skill node not found';
  end if;
  v_node := v_before;
  v_old_parent := v_before.parent_id;
  v_old_path := v_before.path;

  if p_new_parent is null then
    if v_before.kind <> 'category' then
      raise exception 'Only categories can be root nodes';
    end if;
    v_new_depth := 1;
    v_new_path := public.skill_node_slug(v_before.name)::extensions.ltree;
  else
    select * into v_parent from public.skill_nodes where id = p_new_parent for update;
    if not found then
      raise exception 'New parent not found';
    end if;
    if v_parent.path <@ v_before.path then
      raise exception 'A node cannot be moved under its own descendant';
    end if;

    if v_parent.kind = 'category' and v_before.kind not in ('category', 'skill') then
      raise exception 'Categories may only contain categories or skills';
    elsif v_parent.kind = 'skill' and v_before.kind <> 'focus' then
      raise exception 'Skills may only contain focus nodes';
    elsif v_parent.kind = 'focus' and v_before.kind <> 'focus' then
      raise exception 'Focus nodes may only contain focus nodes';
    end if;

    v_new_depth := v_parent.depth + 1;
    v_new_path := (v_parent.path::text || '.' || public.skill_node_slug(v_before.name))::extensions.ltree;
  end if;

  if v_new_path = v_old_path and p_new_parent is not distinct from v_old_parent then
    return jsonb_build_object('moved', false, 'path', v_old_path::text);
  end if;

  select coalesce(max(depth), v_before.depth)
    into v_max_depth
  from public.skill_nodes
  where path <@ v_old_path;

  v_delta := v_new_depth - v_before.depth;
  if v_max_depth + v_delta > 10 then
    raise exception 'Move would exceed the maximum taxonomy depth of 10';
  end if;

  perform set_config('palturo.suppress_skill_guard', 'on', true);

  update public.skill_nodes
  set parent_id = p_new_parent,
      updated_at = now()
  where id = p_node;

  select * into v_node from public.skill_nodes where id = p_node;

  update public.skill_nodes
  set path = (v_node.path::text || substring(path::text from length(v_old_path::text) + 1))::extensions.ltree,
      depth = depth + v_delta,
      updated_at = now()
  where path <@ v_old_path
    and id <> p_node;
  get diagnostics v_descendants = row_count;

  perform set_config('palturo.suppress_skill_guard', 'off', true);

  update public.skill_nodes s
  set is_leaf = not exists (
    select 1 from public.skill_nodes c where c.parent_id = s.id
  )
  where s.id in (p_node, v_old_parent, p_new_parent);

  insert into public.skill_change_log
    (node_id, action, before, after, reason, actor_id)
  values (
    p_node,
    'move',
    to_jsonb(v_before),
    jsonb_build_object(
      'old_parent_id', v_old_parent,
      'new_parent_id', p_new_parent,
      'old_path', v_old_path::text,
      'new_path', v_node.path::text,
      'old_depth', v_before.depth,
      'new_depth', v_node.depth,
      'descendants_moved', v_descendants
    ),
    p_reason,
    p_actor
  );

  return jsonb_build_object(
    'moved', true,
    'path', v_node.path::text,
    'depth', v_node.depth,
    'descendants_moved', v_descendants
  );
end;
$$;

revoke all on function public.admin_move_skill(uuid, uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_move_skill(uuid, uuid, uuid, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- Audit reverts.
-- ---------------------------------------------------------------------------
alter table public.admin_audit_log
  add column if not exists reverted_at timestamp with time zone,
  add column if not exists reverted_by uuid,
  add column if not exists revert_audit_id bigint;

-- ---------------------------------------------------------------------------
-- Managed backups.
-- ---------------------------------------------------------------------------
create table if not exists public.admin_backups (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  scope text[] not null default array['core']::text[],
  status text not null default 'running'
    check (status in ('running', 'complete', 'failed', 'deleted')),
  storage_path text,
  size_bytes bigint,
  checksum text,
  table_counts jsonb,
  total_rows bigint,
  created_by uuid,
  created_at timestamp with time zone not null default now(),
  completed_at timestamp with time zone,
  expires_at timestamp with time zone,
  error text
);
create index if not exists admin_backups_created_idx
  on public.admin_backups (created_at desc);

alter table public.admin_backups enable row level security;
revoke all on public.admin_backups from anon, authenticated;
grant all on public.admin_backups to service_role;

alter table public.moderation_actions enable row level security;
revoke all on public.moderation_actions from anon, authenticated;
grant all on public.moderation_actions to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'admin-backups',
  'admin-backups',
  false,
  52428800,
  array['application/gzip', 'application/json']
)
on conflict (id) do update set public = false;

-- No storage policies are added: only the service role may read/write backups.
