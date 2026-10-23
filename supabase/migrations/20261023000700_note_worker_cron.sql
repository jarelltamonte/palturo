-- Durable note moderation: pg_cron calls the worker every minute via pg_net.
-- The worker secret must exist in both places:
--   1. `supabase secrets set MODERATION_WORKER_SECRET=<value>`
--   2. public.integration_secrets row name='MODERATION_WORKER_SECRET'
-- (the cron command reads the DB copy; the Edge Function reads the env copy).

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Per-project worker URL (change this row when deploying to another project).
insert into public.pipeline_config (key, value)
values (
  'worker_url',
  '"https://yjcrfgvenilptrnudvcb.supabase.co/functions/v1/moderate-notes"'::jsonb
)
on conflict (key) do nothing;

-- One-time moderation pass over notes that predate the queue. Existing rows
-- only enqueue once; later runs skip names that already have a queue row.
insert into public.note_moderation_queue
  (user_id, kind, name, skill_id, note, note_hash, status, attempts)
select us.user_id, us.kind, n.name, us.skill_id, us.note, md5(us.note),
       'pending', 0
from public.user_skills us
join public.skill_nodes n on n.id = us.skill_id
where us.note is not null and btrim(us.note) <> ''
  and not exists (
    select 1 from public.note_moderation_queue q
    where q.user_id = us.user_id and q.kind = us.kind and q.name = n.name
  )
on conflict (user_id, kind, name) do nothing;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'moderate-notes') then
    perform cron.unschedule('moderate-notes');
  end if;
end $$;

select cron.schedule(
  'moderate-notes',
  '* * * * *',
  $cron$
    select net.http_post(
      url := (select value #>> '{}' from public.pipeline_config
              where key = 'worker_url'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-worker-secret',
        (select value from public.integration_secrets
         where name = 'MODERATION_WORKER_SECRET')
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
  $cron$
);
