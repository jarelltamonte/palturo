# Database baseline and migrations

`schema.sql` is a **structural baseline** for project `yjcrfgvenilptrnudvcb`
(generated 2026-10-24 with `supabase db dump --linked --schema public`). It is
the only source of the base tables and extensions, and it is stale as content:
never treat it as the current schema and never skip the migrations that follow
it. The latest migration is `20261121000100_launch_hardening.sql`.

## Current taxonomy

- 9 depth-1 domains.
- 29 selectable skills: 25 at depth 2 plus 4 Programming skills at depth 3.
- 16 depth-3 focus skills (hidden in the picker; stored in
  `user_skills.focus_skill_id`).

Selections live in `user_skills.skill_id` and must target a `kind='skill'`
node (25 at depth 2 plus the 4 depth-3 Programming skills). A more specific
leaf matched by the classifier is stored in `user_skills.focus_skill_id` and
appended to the matching passage as `(focus: ...)`; the kind guard rejects
categories and other non-skill nodes.

`skill_showcases` is the public table discovery reads. The editor keys media by
the depth-2 skill and keeps a specific caption. `connections.skill_name` and
`connections.skill_path` store request context at depth 2.
`connections.request_source` records the discovery surface (`match`, `explore`,
`browse`, or `unknown` for legacy requests) so the recipient can see where the
request came from.

## Rebuild a fresh environment

Run against a Supabase Postgres instance with the base `anon`, `authenticated`,
and `service_role` roles and the `auth` schema already present.

1. Restore `schema.sql` once. It provides the extensions (`ltree`, `vector`,
   `pgcrypto`, `uuid-ossp`, `pg_cron`, `pg_net`, `supabase_vault`), base
   tables, indexes, RLS, and the migrations up to `20261023001700`. Because it
   is a `--schema public` dump it does **not** contain the triggers on
   `auth.users`.
2. Apply `seed.sql` for the taxonomy rows. It is idempotent and must run before
   the kind/level migrations, which expect the original row shape.
3. Mark the baseline migrations applied with
   `supabase migration repair --status applied <id>` through
   `20261023001700`, then apply every later file in `migrations/` in filename
   order. Start with `20261023001800_auth_profile_triggers.sql`; it is the only
   source of the signup and email-sync triggers.
4. Apply `cron.sql` to recreate the rate-limit cleanup and moderation-worker
   jobs.
5. Recreate storage buckets and policies, Edge Function secrets, Resend SMTP,
   and Vault/worker settings from the deployment runbook. They are not part of
   the public schema. The inference provider uses `NIM_API_KEY` or
   `DEEPINFRA_API_KEY` (selected by `inference_provider`).
6. Configure `pipeline_config` (worker URL and embedding weights) and auth
   redirect settings for the new environment.
7. Sign up the first account, then insert it into `admin_users` with role
   `owner` (see the root README).
8. In Supabase Realtime settings, turn off "Allow public access". Private
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
supabase functions deploy admin-api
supabase functions deploy delete-account
supabase functions deploy moderate-notes --no-verify-jwt
```

`classify-skill` moderates custom skill names, attaches or creates a node, and
places the selectable skill in `user_skills` with the leaf as focus. It cleans
casing and spacing, and a near-spelling of an existing node attaches to that
node instead of creating a duplicate. A high-confidence new node is accepted
immediately (`status = 'approved'`, visible) and marked `auto_approved`; a
lower-confidence creation is queued as `pending` for the admin panel. Verdicts
are written to `skill_moderation_log`, linked to the node through
`skill_node_id`.

Pass `dry_run: true` to run the full decision without writing `user_skills` or
new `skill_nodes`. Onboarding uses a dry run when a chip is created and repeats
the call without the flag on save, so abandoned onboarding does not consume the
skill cap.

## Important

- `schema.sql` is the structural baseline (extensions, tables, indexes, RLS)
  captured on 2026-10-24. It is stale as content and does not replace the
  migrations, but no migration creates the base tables or `ltree`/`vector`
  extensions, so a brand-new database still starts from it.
- After restoring the baseline, mark the migrations it already reflects as
  applied (`supabase migration repair --status applied <id>` through
  `20261023001700`), then apply later migrations normally, starting with
  `20261023001800_auth_profile_triggers.sql`. Replaying the baseline migrations
  collides with existing objects; skipping `20261023001800` leaves signup
  without a profile row.
- The baseline ends with explicit anon/authenticated revokes for existing
  objects and default-privilege revokes that keep future postgres-created
  public tables, sequences, and functions private by default.
- Migrations after the baseline are forward-only and should be applied normally.
- `seed.sql` contains only taxonomy rows; it has no profiles, messages,
  credentials, or secrets.
