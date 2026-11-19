-- Lightweight client error reporting. The app posts uncaught Flutter/async
-- errors here; only the service role can read the table, and the RPC is
-- rate-limited so a broken build cannot flood the database.
create table if not exists public.client_errors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  platform text not null default '',
  app_version text not null default '',
  route text not null default '',
  message text not null,
  stack text,
  created_at timestamp with time zone not null default now()
);

create index if not exists client_errors_created_idx
  on public.client_errors (created_at desc);
create index if not exists client_errors_user_idx
  on public.client_errors (user_id, created_at desc);

alter table public.client_errors enable row level security;
revoke all on public.client_errors from public, anon, authenticated;
grant all on public.client_errors to service_role;

create or replace function public.report_client_error(
  p_platform text,
  p_app_version text,
  p_route text,
  p_message text,
  p_stack text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_subject uuid;
  v_ip text;
begin
  v_ip := coalesce(
    nullif(
      split_part(
        coalesce(
          (
            nullif(current_setting('request.headers', true), '')::jsonb
              ->> 'x-forwarded-for'
          ),
          ''
        ),
        ',',
        1
      ),
      ''
    ),
    'unknown'
  );
  v_subject := coalesce(v_uid, md5(v_ip)::uuid);

  if not public.consume_rate_limit(v_subject, 'client_error', 20, 3600) then
    return;
  end if;

  insert into public.client_errors (
    user_id, platform, app_version, route, message, stack
  )
  values (
    v_uid,
    left(coalesce(p_platform, ''), 40),
    left(coalesce(p_app_version, ''), 40),
    left(coalesce(p_route, ''), 300),
    left(coalesce(p_message, 'Unknown error'), 2000),
    left(p_stack, 8000)
  );
end;
$$;

revoke all on function public.report_client_error(text, text, text, text, text)
  from public;
grant execute on function public.report_client_error(text, text, text, text, text)
  to anon, authenticated, service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'client-error-retention') then
    perform cron.unschedule('client-error-retention');
  end if;
end $$;

select cron.schedule(
  'client-error-retention',
  '35 3 * * *',
  $cron$
    delete from public.client_errors
    where created_at < now() - interval '90 days';
  $cron$
);
