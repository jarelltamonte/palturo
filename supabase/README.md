# Database baseline and migrations

`schema.sql` is the public-schema snapshot of project `yjcrfgvenilptrnudvcb`
(generated 2026-10-24 with `supabase db dump --linked --schema public`). It is
documentation and schema of record, not an automatically applied migration.

Forward-only migrations in `migrations/` are the source of change after that
baseline. The latest migration is
`20261114001200_showcase_cache_invalidation.sql`.

## Current taxonomy

- 9 depth-1 categories.
- 26 depth-2 selectable skills.
- 16 depth-3 leaves.

Selections live in `user_skills.skill_id` at depth 2. A specific leaf matched by
the classifier is stored in `user_skills.focus_skill_id` and appended to the
matching passage as `(focus: ...)`. The depth-2 guard trigger rejects deeper
selections.

`skill_showcases` is the public table discovery reads. The editor keys media by
the depth-2 skill and keeps a specific caption. `connections.skill_name` and
`connections.skill_path` store request context at depth 2.

## Rebuild a fresh environment

Run against a Supabase Postgres instance. The base `anon`, `authenticated`,
and `service_role` roles and the `auth` schema must already exist.

1. Apply `schema.sql`. It starts with the extension prerequisites (`ltree`,
   `vector`, `pgcrypto`, `uuid-ossp`, `pg_cron`, `pg_net`,
   `supabase_vault`) and then creates the public schema.
2. Apply `seed.sql` for the 51 taxonomy `skill_nodes` rows (parent-first,
   idempotent via `ON CONFLICT`).
3. Apply the auth trigger migration
   `migrations/20261023001800_auth_profile_triggers.sql` (profile creation on
   signup and email mirroring). Auth internals are intentionally not in the
   public dump.
4. Apply `cron.sql` to recreate the rate-limit cleanup and moderation-worker
   jobs.
5. Recreate storage buckets and policies, Edge Function secrets, Resend SMTP,
   and Vault/worker settings from the deployment runbook. They are not part of
   the public schema.
6. Configure `pipeline_config` (worker URL and embedding weights) and auth
   redirect settings for the new environment.
7. In Supabase Realtime settings, turn off "Allow public access". Private
   chat/notification topics are enforced by
   `migrations/20261107000300_realtime_topic_acl.sql`; with public access on, a
   modified client could still join a public topic.

## Storage buckets

| Bucket | Public | Limit | Contents |
| --- | --- | --- | --- |
| `profile-media` | yes | 20 MiB | profile photos |
| `profile-photos` | yes | 20 MiB | alternate photo bucket |
| `avatars` | yes | 10 MiB | avatars |
| `skill-showcases` | yes | 50 MiB | showcase images and videos |
| `skill-proofs` | no | 20 MiB | legacy private proofs, signed on read |

## Edge Functions

```sh
supabase functions deploy classify-skill
supabase functions deploy get-matches
supabase functions deploy generate-embeddings
supabase functions deploy delete-account
supabase functions deploy moderate-notes --no-verify-jwt
```

`classify-skill` moderates custom skill names, attaches or creates a node, and
places the depth-2 parent in `user_skills` with the leaf as focus. It cleans
casing and spacing, and a near-spelling of an existing node attaches to that
node instead of creating a duplicate. Verdicts are written to
`skill_moderation_log`.

Pass `dry_run: true` to run the full decision without writing `user_skills` or
new `skill_nodes`. Onboarding uses a dry run when a chip is created and repeats
the call without the flag on save, so abandoned onboarding does not consume the
skill cap.

## Important

- The baseline already contains the end state of migrations `000100` through
  `001700`. Do not apply those migrations after restoring `schema.sql`; use the
  migrations only to evolve an existing database.
- The baseline ends with explicit anon/authenticated revokes for existing
  objects and default-privilege revokes that keep future postgres-created
  public tables, sequences, and functions private by default.
- If you use `supabase db push` after restoring, first mark the baseline
  migrations applied with
  `supabase migration repair --status applied <ids>` through
  `20261023001800`; otherwise push replays them and collides.
- Migrations after the baseline are forward-only and should be applied normally.
- `seed.sql` contains only taxonomy rows; it has no profiles, messages,
  credentials, or secrets.
