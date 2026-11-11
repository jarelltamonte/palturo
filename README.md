# palturo

A Flutter client for the PalTuro skill-exchange service.

## Build configuration

The app no longer reads a bundled `.env` file. Supabase configuration is
injected at build time and compiled into the app by `--dart-define`:

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

For local runs, pass the same defines:

```powershell
flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Only the project URL and publishable key belong in a client build. Never pass a
personal access token, service-role key, or other account-level credential;
`--dart-define` values are extractable from the compiled app.

Before distributing an artifact, run the release gate:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\pre_release_check.ps1
```

It runs `dart analyze` and `tool/check_no_bundled_secrets.dart`, which scans the
packaged output (`build/app/outputs`, `build/web`, or an iOS build) plus
`build/flutter_assets` for `.env` files, symlinks, `sbp_` tokens,
`SUPABASE_PAT`, and `SUPABASE_SERVICE_ROLE_KEY` material. APK/AAB/IPA/ZIP/JAR
archives are decompressed and their entries checked. It exits `1` on a hit and
`2` when no packaged artifact was found. Pass a file or directory to check a
specific artifact:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\pre_release_check.ps1 -ArtifactPath .\build\app\outputs\flutter-apk\app-release.apk
```

Treat any hit as a release blocker and rotate the credential.
