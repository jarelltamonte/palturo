# Database baseline

`schema.sql` is the public-schema snapshot of project `yjcrfgvenilptrnudvcb`
(generated 2026-10-24 with `supabase db dump --linked --schema public`).
It is documentation/schema of record, not an automatically applied migration.

## Rebuild a fresh environment

Run against a Supabase Postgres instance (the base `anon`, `authenticated`,
`service_role` roles and `auth` schema must already exist):

1. Apply `schema.sql` — it starts with the extension prerequisites
   (`ltree`, `vector`, `pgcrypto`, `uuid-ossp`, `pg_cron`, `pg_net`,
   `supabase_vault`) and then creates the public schema.
2. Apply `seed.sql` for the 51 taxonomy `skill_nodes` rows (parent-first,
   idempotent via `ON CONFLICT`).
3. Apply the auth trigger migration
   `migrations/20261023001800_auth_profile_triggers.sql` (profile creation on
   signup **and** email mirroring). `auth` internals are intentionally not in
   the public dump.
4. Apply `cron.sql` to recreate the rate-limit cleanup and moderation-worker
   jobs.
5. Recreate storage buckets/policies, Edge Function secrets, Resend SMTP, and
   Vault/worker settings from the deployment runbook; they are not part of the
   public schema.
6. Configure `pipeline_config` (worker URL / embedding weights) and auth
   redirect settings for the new environment.

## Important

- The baseline already contains the end state of migrations `000100`–`001700`.
  Do **not** apply those migrations after restoring `schema.sql`; use the
  migrations only to evolve an existing database.
- The baseline ends with explicit anon/authenticated revokes for existing
  objects and default-privilege revokes that keep future postgres-created
  public tables, sequences, and functions private by default.
- If you use `supabase db push` after restoring, first mark the baseline
  migrations applied with `supabase migration repair --status applied <ids>`
  through `20261023001800`; otherwise push replays them and collides.
- Migrations after the baseline are forward-only and should be applied normally.
- `seed.sql` contains only taxonomy rows; it has no profiles, messages,
  credentials, or secrets.
