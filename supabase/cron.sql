-- Scheduled maintenance for PalTuro (run once after restoring schema.sql).
-- Requires pg_cron/pg_net and the Vault secret `moderation_worker_secret`.
do $$
begin
  perform cron.unschedule('rate-limit-cleanup');
exception when others then null;
end $$;

select cron.schedule(
  'rate-limit-cleanup',
  '15 * * * *',
  $cron$delete from public.rate_limits where window_start < now() - interval '1 day';$cron$
);

do $$
begin
  perform cron.unschedule('moderate-notes');
exception when others then null;
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
        (select decrypted_secret from vault.decrypted_secrets
         where name = 'moderation_worker_secret'
         order by created_at desc limit 1)
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
  $cron$
);
