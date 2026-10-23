-- B12: the moderation worker secret lives in Supabase Vault, not in a normal
-- table. The Edge Function env copy is set separately with `supabase secrets`.
-- Create the Vault entry once per project:
--   select vault.create_secret('<value>', 'moderation_worker_secret', ...);

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
        (select decrypted_secret from vault.decrypted_secrets
         where name = 'moderation_worker_secret'
         order by created_at desc limit 1)
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 120000
    );
  $cron$
);
