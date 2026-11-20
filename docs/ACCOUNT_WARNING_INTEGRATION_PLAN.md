# Account Warning Integration — Implementation Plan

> **Status:** Proposed, not started.
> **Owner:** Consumer app + Supabase + admin console.
> **Last updated:** 2026-11-20.
> **Scope:** Make an account warning visible, attributable, and acknowledgeable in
> the consumer app without changing authentication, matching, or the existing
> audit/revert path in a breaking way.
> **Repo:** `C:\Users\Xander\Desktop\PalTuro\palturo`
> **Admin repo:** `C:\Users\Xander\Desktop\PalTuro\palturo-admin`
> **Supabase project:** `yjcrfgvenilptrnudvcb`
> **Production:** live. Every step below is additive and flag-gated.

This file is the source of truth for a fresh session. Update the status and
changelog as work lands.

---

## 1. Direct answer: what happens today

A warning is recorded, but the warned user never learns about it.

When an admin resolves a report with **Warn**:

1. `admin-api` (`supabase/functions/admin-api/index.ts`, `moderation.resolveReport`)
   increments `profiles.warning_count` and sets `profiles.last_warned_at`.
2. It inserts a row in `moderation_actions` and an append-only `admin_audit_log`
   entry.
3. It writes the report status/action.

Nothing else happens:

- No `notifications` row is created.
- No RPC exposes warning details to the consumer app.
- `lib/` contains no reference to `warning_count`, `last_warned_at`, or a
  warning notification kind.
- `AppNotificationKind` has no warning value, so an unknown kind would render as
  a generic “update”.
- The only visible effect is in the admin console (`ModerationPage`, user
  detail) and in analytics.

So today: **a warning is an internal note with a counter, not a user-facing
consequence.** All 51 production profiles currently have `warning_count = 0`,
so there is no historical warning data to migrate.

Suspension and ban are different: they call the GoTrue admin API with a
`ban_duration`, so the account cannot sign in. Warnings have no enforcement.

---

## 2. Goals

- The warned user sees the warning in-app: what happened, when, and what is
  expected next.
- The warning persists (not a transient toast) and can be acknowledged.
- Admins can attach a short user-facing message without exposing reporter
  identity, report snapshots, or internal notes.
- Warning history is queryable by admins and reversible through the existing
  audit path.
- No change to sign-in, matching, RLS of profiles, or existing notification
  kinds.
- Old app versions never break; warnings are gated behind a server flag until
  the new client is in the field.

### Non-goals (v1)

- Automatic escalation (warn → suspend) and thresholds.
- Appeals workflow or email delivery.
- Public warning badges on profiles.
- Editing warning history.

---

## 3. Product decisions (recommended defaults)

| Decision | Recommendation |
|---|---|
| Where the user sees it | Activity notification + **Account standing** section in Account settings |
| Push notification | Yes, but not disableable by category; master notification toggle and OS permission still apply |
| Can the user dismiss without reading? | The notification can be marked read; the Account standing item stays until acknowledged |
| User-facing reason | Admin picks a category and a required short message; internal reason stays admin-only |
| Warning expiry | None in v1; only explicit revoke |
| Counter | `profiles.warning_count` becomes derived from active warnings |
| Old clients | No warning notifications until `account_warning_notifications_enabled` is turned on after app adoption |
| Public visibility | Never |

---

## 4. Data model

New table `public.account_warnings` (additive; no existing table changes).

```sql
create table public.account_warnings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  report_id uuid references public.reports(id) on delete set null,
  category text not null default 'other'
    check (category in ('spam', 'harassment', 'irrelevant', 'other')),
  message text not null check (char_length(message) between 1 and 500),
  internal_reason text,
  issued_by uuid,
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid,
  revoke_reason text
);

create index account_warnings_user_idx
  on public.account_warnings (user_id, created_at desc);

-- One active warning per report; a retry cannot double-warn.
create unique index account_warnings_active_report_idx
  on public.account_warnings (report_id)
  where report_id is not null and revoked_at is null;
```

Why a table instead of only a counter and a notification:

- The counter loses *why* and *when*.
- Notifications are mutable presentation rows; warning history must survive
  read/dismiss and be revocable.
- Revoking from the audit trail needs a stable target row.

### Counter sync

A trigger keeps the existing columns truthful so every current admin screen
keeps working:

```sql
create or replace function public.sync_account_warning_count()
returns trigger language plpgsql security definer set search_path = public as $$
declare target uuid := coalesce(new.user_id, old.user_id);
begin
  update public.profiles p
  set warning_count = (
        select count(*) from public.account_warnings w
        where w.user_id = target and w.revoked_at is null
      ),
      last_warned_at = (
        select max(w.created_at) from public.account_warnings w
        where w.user_id = target and w.revoked_at is null
      )
  where p.id = target;
  return null;
end $$;

create trigger account_warnings_count
after insert or update of revoked_at or delete on public.account_warnings
for each row execute function public.sync_account_warning_count();
```

`admin-api` stops incrementing the counter directly; the trigger becomes the
single source of truth. A one-time reconciliation (all zero today) is a no-op.

### Access

- `revoke all on public.account_warnings from anon, authenticated;`
- RLS enabled, no direct table grants.
- Read/ack through `security definer` RPCs that check `auth.uid()`.
- The admin API uses the service role.
- Do **not** expose warnings through `get_public_profile` or `profiles` select.

---

## 5. Server changes

### 5.1 Issue a warning atomically

New RPC `admin_issue_warning` (service role only). It performs, in one
transaction:

1. insert `account_warnings`;
2. insert a `notifications` row
   `kind = 'account_warning'`,
   payload `{ warning_id, category, count, issued_at }`;
3. insert `moderation_actions`;
4. leave the report update and audit insert to the caller, or accept the
   report id and update it here (preferred for warn actions).

The counter updates through the trigger.

Validation: user is not the acting admin, category in the allowlist, message
1–500 chars, report belongs to the user, no active warning for the report.

### 5.2 User RPCs

```sql
get_my_warnings()
-- returns id, category, message, created_at, acknowledged_at,
-- plus count of active warnings; revoked rows excluded
```

```sql
acknowledge_warning(p_warning uuid)
-- security definer, auth.uid() = user_id, idempotent, sets acknowledged_at
```

### 5.3 Revoke

`admin_revoke_warning(p_warning uuid, p_actor uuid, p_reason text)`,
service-only:

- sets `revoked_at`, `revoked_by`, `revoke_reason`;
- leaves the notification row but marks the Account standing entry as removed;
- trigger recomputes the counter and `last_warned_at`;
- writes an audit action `warning.revoke`.

The existing audit revert for `report.resolve` must call this when
`before.report.action_taken = 'warn'` instead of blindly restoring the counter
from the snapshot. That is the only edit to the regression-sensitive revert
path, and it is covered by tests.

### 5.4 Notification handling

`notify()` already accepts any kind. No change to `list_notifications` is
required for the row to appear; its actor join returns `null` for the new kind,
which the app already handles. Ensure the `possible_match` filter does not
exclude it (it does not).

Add a config flag `account_warning_notifications_enabled` (boolean, default
`false`) in `pipeline_config`. When false, the warning row is still created but
no notification is inserted. This is the rollout gate for old clients.

### 5.5 Migration set

1. `2026xxxx_account_warnings.sql` — table, indexes, trigger, RLS, revokes.
2. `2026xxxx_admin_warning_rpcs.sql` — issue/revoke/get/acknowledge RPCs.
3. `2026xxxx_warning_config_flag.sql` — config key with default false.

All additive. No column drops, no signature changes to existing RPCs.

---

## 6. Admin console changes

`palturo-admin`:

- **Resolve dialog** (`ModerationPage`): when action is **Warn**, reveal:
  - category select (spam, harassment, irrelevant, other);
  - required “Message to the user” textarea (1–500, pre-filled policy copy,
    editable);
  - internal reason stays the existing field.
- **User detail**: Warning history (active/acknowledged/revoked) with message,
  date, actor, and a Revoke action.
- **Moderation report detail**: show the warning and its acknowledgment state.
- **Audit**: render `warning.issue` / `warning.revoke`; revert works.
- **Analytics**: no change required; optionally count active warnings in Safety
  later.

Compatibility: the API accepts missing `warning_category`/`user_message` from
an old console build and falls back to `other` plus a default message. That
prevents a half-deployed console from failing resolutions.

---

## 7. Consumer app changes

`palturo/lib`:

1. `models/app_notification.dart`
   - add `accountWarning('account_warning')`;
   - add `bool get isAccountNotice`.
2. `screen/activity_presentation.dart`
   - kind `account_warning` → title “Account warning”,
     body from payload message/category, icon `Icons.shield_outlined`,
     destination `accountStanding`.
3. `screen/notifications_page.dart`
   - count it under **Updates**;
   - tapping opens Account settings (or a dedicated standing sheet), marks read.
4. `services/notification_presenter.dart`
   - bypass category toggles for account notices; keep master toggle/quiet hours;
   - route to account standing.
5. `services/local_notification_service.dart`
   - map to the activity channel, payload route `account_standing`.
6. `screen/account/account_settings_page.dart`
   - new **ACCOUNT STANDING** section: active warning count, each warning’s
     date/message, an **Understood** button calling `acknowledge_warning`;
   - hide the section entirely when there are no warnings.
7. Optional (second release): a single non-blocking Home banner for an
   unacknowledged warning, linking to the section. Not required for v1.

Copy rules: neutral, no reporter identity, no report snapshot, no threats. The
admin-authored message is the only free text shown.

Tests: model parsing, presentation copy, filter counts, account section with
0/1/N warnings, acknowledge idempotency, realtime insert, old unknown kind
behavior.

---

## 8. Live production rollout

Order matters because the app is live.

1. **Apply migrations** with the notification flag off. Existing behavior is
   byte-for-byte unchanged.
2. **Deploy `admin-api`** with the new optional fields and RPC calls. Old
   console payloads still work.
3. **Deploy admin console** with the warning message/history UI.
4. **Ship the consumer app** and monitor adoption through `client_errors.app_version`
   and store metrics.
5. **Enable `account_warning_notifications_enabled`.** Test first with an
   internal account:
   - admin warns the test account;
   - the account receives one notification, opens Account standing, acknowledges;
   - admin sees the acknowledgment;
   - revoke removes it from both sides and decrements the counter.
6. **Watch** for 24–48 hours: notification errors, account-screen errors,
   duplicate warnings, counter drift.
7. Announce the policy to moderators.

### Why the flag

An old client maps `account_warning` to `unknown`, which currently surfaces as a
generic update under **Updates**. Turning the flag on only after adoption avoids
confusing users on old builds. Warnings still record while the flag is off; only
delivery waits.

---

## 9. Regression guards

- No changes to `profiles` columns, auth bans, matching, or existing RPC
  signatures.
- No new grants on `profiles` or `notifications`.
- `list_notifications` untouched.
- Audit revert remains the only mutation path for resolved reports; its warning
  branch is additive.
- Existing notification kinds, filters, and preferences unchanged.
- New table is service-only; no RLS policy widening.
- Feature flag defaults off; no warning notification is sent without an explicit
  config change.
- If the consumer app is unavailable, admin warning still records history and
  the counter; nothing blocks moderation.

---

## 10. Test matrix

**SQL**

- Insert warning → counter 1, `last_warned_at` set.
- Insert second active warning for the same report → rejected.
- Revoke → counter 0, `last_warned_at` null.
- Acknowledge twice → idempotent.
- RLS: another user cannot select/acknowledge via RPC.
- Empty state: no warnings returns an empty array and zero.

**Admin API**

- Warn requires message/category and validates length.
- Cannot warn self, or an admin without owner approval (existing rule).
- Notification created once; retry does not duplicate.
- Audit entry + revert revokes the warning and restores the counter.
- Old payload without message still resolves using defaults.

**Consumer app**

- Notification appears in Activity/Updates and local push.
- Account standing shows the message and count.
- Acknowledgment persists across restart.
- Revoked/expired warnings disappear.
- Unknown kinds still render safely.
- Existing flows: requests, matches, chats, skill moderation, possible match.

**E2E**

- Two-account production-like run: admin warn → user notify → acknowledge →
  admin sees it → revoke → gone.
- Admin smoke suite 23/23.
- Flutter analyzer + test suite.

---

## 11. Rollback

- Set `account_warning_notifications_enabled` back to `false`; delivery stops.
- Revoke test warnings; the trigger restores counters.
- The table and RPCs are harmless if unused; no destructive rollback needed.
- The admin console can keep the history UI reading the table.
- Existing report resolution still works without a warning message (defaults).

---

## 12. Open questions

1. Should a third active warning auto-suspend? (Recommend: no, keep human
   review; revisit after data.)
2. Should warnings expire after N days? (Recommend: no expiry in v1.)
3. Should the user be able to appeal from the warning card? (Recommend: link to
   Support, no formal workflow.)
4. Should the notification survive the user disabling “Activity updates”?
   (Recommend: yes, it is an account notice.)
5. Do we need email for users who never open the app? (Out of scope; push +
   in-app first.)

---

## 13. Changelog

- 2026-11-20 — Plan created. Current warning path audited; no user-facing
  warning exists. Proposed table, RPCs, admin/app changes, flag-gated rollout.
