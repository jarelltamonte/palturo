# PalTuro

A mobile application for community-based Filipino cultural skill exchange.

## Configuration

The app reads its Supabase configuration from compile-time defines. It is **not**
read from a bundled asset and `.env` is not committed or shipped.

1. Copy `.env.example` to `.env`.
2. Fill in your project values.
3. Run or build with `--dart-define-from-file`:

```sh
flutter run --dart-define-from-file=.env
flutter build apk --dart-define-from-file=.env
flutter build web --dart-define-from-file=.env
```

You can also pass the values directly:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

If the values are missing, the app starts on a configuration screen instead of
crashing. Only the publishable (anon) key belongs here — never a service-role key.

## Backend functions

```sh
supabase functions deploy get-matches
supabase functions deploy generate-embeddings
supabase functions deploy delete-account
supabase functions deploy moderate-notes --no-verify-jwt
```

`delete-account` requires `verify_jwt = true` and is configured in
`supabase/config.toml`.

## Note moderation worker

`moderate-notes` runs as a server-side queue worker, not from the app. It is
deployed with `verify_jwt = false` and authenticates with `x-worker-secret`.
Set the same random secret in both places:

```sh
supabase secrets set MODERATION_WORKER_SECRET=<random-64-hex>
# then insert the same value into public.integration_secrets
# under name = 'MODERATION_WORKER_SECRET'
```

The `20261023000700_note_worker_cron.sql` migration schedules the worker every
minute via `pg_cron`/`pg_net`. Pending notes stay owner-only until the worker
approves them; custom-skill notes remain private in `user_skill_notes`.

For another Supabase project, update the `pipeline_config.worker_url` row before
applying the cron migration (it defaults to this project's function URL).

