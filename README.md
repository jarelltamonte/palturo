# PalTuro

PalTuro is a community-based Filipino cultural skill exchange. Members teach
what they know and learn what they want through reciprocal matches, chat, and
short skill showcases.

The product is mobile-first. The same Flutter codebase also runs as a desktop
web app with a sidebar shell, wider content columns, and framed routes. The
phone layout is the source of truth and is unchanged below 900 px.

## Stack

- Flutter 3.x (Dart) for iOS, Android, and web.
- Supabase for Postgres, Row Level Security, Auth, Storage, Realtime, and Edge
  Functions.
- Cloudflare Worker `palturo-auth` for `palturo.app` and `www.palturo.app`.
- A separate static project at `../palturo-auth-web` for the confirmation and
  password-reset pages served from the same domain.

## Quick start

1. Copy `.env.example` to `.env` and fill in the project values.
2. Run the app:

```sh
flutter run -d web-server --web-port 5319 --dart-define-from-file=.env
flutter run --dart-define-from-file=.env
```

3. Run the gates:

```sh
flutter analyze --no-pub
flutter test
```

If Supabase values are missing, the app opens a configuration screen instead
of crashing. Only the publishable (anon) key belongs in `.env`.

> Do not put `SUPABASE_PAT` or a service-role key in `.env`.
> `--dart-define-from-file` compiles every value in that file into the client.
> Keep CLI tokens in `.env.cli` (gitignored) and load them only in your shell.

## Current product behavior

### Authentication and onboarding

- Email sign-up, login, password reset, and account deletion.
- Onboarding collects a role, skills, and optional availability, language, and
  learning-style details.
- Skills are selected at **depth 2** of the taxonomy: 26 choices such as
  Farming, Filipino Cooking, Filipino Dessert Making, Filipino Embroidery,
  Programming, Sewing, Painting, and Philippine Script Writing.
- The interests step has a search field. It filters the depth-2 chips, accepts
  Enter for an exact match, and offers `Create "<name>"` for a new skill.
- Every custom skill goes through the `classify-skill` Edge Function before it
  is saved. A rejection, or an unavailable classifier, blocks the save instead
  of storing unmoderated text.
- Selected chips move to the top of the list. The step allows 3 learning skills
  and 2 teaching skills.
- A mentor can save without a showcase. The editor explains that showcase media
  is what makes the profile discoverable; Browse, Explore, and For You exclude
  teaching profiles without media until one is added.
- A user with no role or no skills sees a setup checklist on For You instead of
  a match search: a complete-profile note, Explore, and Update Profile.

### Discovery

- **For You** ranks reciprocal matches with the `get-matches` Edge Function and
  excludes blocks, existing Pals, pending requests, and teaching profiles with
  no showcase media.
- **Explore** is an endless random deck of new people. It excludes self, blocks,
  existing connections, and profiles without discovery media. The client
  deduplicates recently shown cards and prefetches near the end.
- **Browse** shows the nine depth-1 categories, hides branches with nobody for
  the active role, and shows live counts. The category page lists depth-2
  skills and filters empty child skills.

### Chat

- Realtime messages with typing, presence, read receipts, drafts, mute, mark
  unread, in-chat search, and pagination.
- Long press a message for Copy and, for your own message, Delete message.
- Deleted messages become tombstones: the body becomes `Message Deleted`, the
  row keeps its timestamp and `deleted_at`, and the bubble cannot be tapped,
  long-pressed, or copied. The peer sees the ghost over Realtime UPDATE.
- Long press a chat for Delete conversation. It clears the messages and keeps
  the Pal connection.
- The room jumps to the true bottom after the lazy list refines its extent, so
  the newest message is never one line behind the composer.

### Media

- Profile photos and avatars are compressed on pick (1920 px, quality 85) and
  uploaded to `profile-media` or `profile-photos`.
- Showcase images and short videos upload to the public `skill-showcases`
  bucket. Videos autoplay muted and loop on discovery cards.
- Upload limits: 20 MiB for profile media and legacy proofs, 10 MiB for avatars,
  50 MiB for showcases. The client sends an explicit content type and rejects
  HEIC with a clear message.
- The production CSP allows Supabase media in `img-src`, `connect-src`, and
  `media-src`.

### Notifications

- The Requests badge counts unread incoming connection requests only.
- Banners respect notification preferences, are enriched with the person and
  skill behind a realtime row, and never require an Overlay.
- Realtime handles insert, update, and delete on notifications. Withdrawn
  requests remove their banner and stale request notifications are deleted when
  a connection is answered or removed.

## Project layout

```
lib/
  authentication/     login, register, password reset, legal dialogs
  onboarding/         intro, role, interests, details, review
  screen/             For You, Browse, Chats, Requests, Profile, Settings
  screen/card/        person card, request card, skills card
  services/           Supabase adapters, notifications, media, deck state
  theme/              colors, spacing, type, motion
  widgets/            shared chrome, banners, deck views, responsive shell
supabase/
  migrations/         forward-only database changes
  functions/          classify-skill, get-matches, generate-embeddings,
                      delete-account, moderate-notes
  schema.sql          public-schema baseline
  seed.sql            taxonomy seed
cloudflare/           Worker config and HTTPS redirect
web/                  Flutter web shell, splash, and CSP headers
test/                 widget, unit, and regression tests
docs/                 auth runbook and historical reports
```

### Responsive shell

| Width | Navigation | Content |
| --- | --- | --- |
| 900 px and up | Left sidebar, no bottom bar | For You 760, Browse 1120, Chats/Requests/Profile 820, pushed pages 820, auth/onboarding 560 |
| 601 to 899 px | Bottom bar | Single 600 px column |
| 600 px and below | Bottom bar | Full-width phone layout |

`lib/widgets/responsive_shell.dart` returns the phone tree untouched below
900 px. There is no desktop-only widget tree that a phone can receive.

## Data model and taxonomy

- 9 depth-1 categories, 26 depth-2 selectable skills, 16 depth-3 leaves.
- Selections are stored in `user_skills.skill_id` at depth 2.
- A specific leaf typed or matched by the classifier is stored in
  `user_skills.focus_skill_id`. It is appended to the matching passage as
  `(focus: ...)` so specificity still counts without exposing an oddly specific
  skill in the picker.
- `profiles.teaching_skills` and `learning_skills` are denormalized mirrors of
  `user_skills`, kept in sync by `rebuild_skill_array`.
- `skill_showcases` is the public showcase table read by discovery. The editor
  keys media by the depth-2 skill and keeps a specific caption such as
  `Cooking Pinakbet`.
- `connections.skill_name` and `skill_path` store the request context at
  depth 2.

Key RPCs include `save_user_skills`, `set_skill_showcases`,
`get_public_profile`, `browse_random_users`, `browse_skill_users`,
`match_candidates`, `get_conversations`, `get_conversation`, `send_message`,
`delete_message`, `delete_conversation`, and `send_connection_request`.

## Backend and migrations

Apply forward-only migrations in `supabase/migrations/` to the linked project.
The latest migration is `20261114001200_showcase_cache_invalidation.sql`.

Storage buckets:

| Bucket | Public | Limit | Contents |
| --- | --- | --- | --- |
| `profile-media` | yes | 20 MiB | profile photos |
| `profile-photos` | yes | 20 MiB | alternate photo bucket |
| `avatars` | yes | 10 MiB | avatars |
| `skill-showcases` | yes | 50 MiB | showcase images and videos |
| `skill-proofs` | no | 20 MiB | legacy private proofs, signed on read |

Deploy the Edge Functions:

```sh
supabase functions deploy classify-skill
supabase functions deploy get-matches
supabase functions deploy generate-embeddings
supabase functions deploy delete-account
supabase functions deploy moderate-notes --no-verify-jwt
```

`classify-skill` is the moderation gate for custom skill names. It judges the
skill name, attaches an existing node or creates a pending node, and places the
depth-2 parent in `user_skills` with the leaf as focus. Rejections are logged to
`skill_moderation_log`.

`moderate-notes` runs as a server-side queue worker, not from the app. It is
deployed with `verify_jwt = false` and authenticates with `x-worker-secret`.
Set the same random secret in the function secrets and the Vault entry used by
`pg_cron`:

```sh
supabase secrets set MODERATION_WORKER_SECRET=<random-64-hex>
```

```sql
select vault.create_secret(
  '<the same value>',
  'moderation_worker_secret',
  'pg_cron worker auth'
);
```

The note worker is scheduled by `20261023000700_note_worker_cron.sql`. Pending
notes stay owner-only until approved; custom-skill notes remain private in
`user_skill_notes`.

## Web deployment

The app is built to `build/web`, merged with the auth assets into
`build/web-merged`, and deployed with the Worker config:

```sh
flutter build web --release --dart-define-from-file=.env.production
Copy-Item build\web\* build\web-merged -Recurse -Force
Copy-Item web\_headers build\web-merged\_headers -Force
npx wrangler deploy --config cloudflare/wrangler.jsonc
```

`web/_headers` contains the CSP. `media-src` must include the Supabase origin or
showcase videos are blocked. The auth pages (`/reset`, `/confirm`) live in
`build/web-merged` and must survive the merge.

The static confirmation and reset project is `../palturo-auth-web`. See
[`docs/AUTH_EMAIL_LINKS.md`](docs/AUTH_EMAIL_LINKS.md) for the email templates,
redirect URLs, and verification checklist.

## Testing

- `flutter analyze --no-pub`: clean.
- `flutter test`: 217 tests.
- Coverage includes the desktop shell, exhausted deck, Explore deck, seen-card
  persistence, Browse filters, onboarding search and depth-2 options, login
  keyboard behavior, banner without an Overlay, notification badge and realtime
  state, request-card rollback, chat deletion and tombstones, showcase
  attachments, media limits, and profile parsing.

Historical reports and audits live in `docs/*.html` and `docs/*.pdf`. They
describe earlier passes and are not a substitute for the current README.

## Security notes

- RLS is enabled on every public table.
- Security-definer functions set `search_path`.
- Profile and showcase URLs are constrained to the project storage origin.
- The CSP allows only self, Supabase, and the font/script hosts the app needs.
- Anonymous execution is limited to helper and trigger functions.
- Never commit `.env`, `.env.cli`, or `.env.cloudflare`.

## Known limitations

- Native iOS and Android builds are not exercised by the web test suite.
- The desktop shell is verified in Chrome at 1440, 900, 800, and 390 px.
- Match caching is cleared when a connection or showcase changes; at a larger
  scale it should be scoped per role or candidate set.
- Profile skill arrays are denormalized; the parser and trigger guard against
  nulls, but `user_skills` remains the source of truth.
- The app does not currently expose a full session/device management screen.
