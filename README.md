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
supabase functions deploy classify-skill
supabase functions deploy generate-embeddings
supabase functions deploy delete-account
```

`delete-account` requires `verify_jwt = true` and is configured in
`supabase/config.toml`.
