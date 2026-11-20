# Account Warning Integration — Implementation Plan

> **Status:** Implemented (2026-11-20). Backend, admin console, and Flutter code
> are in place; the consumer app needs its normal release to reach users.
> **Owner:** Consumer app + Supabase + admin console.
> **Last updated:** 2026-11-20.
> **Scope:** Make an account warning visible, attributable, acknowledgeable, and
> time-limited in the consumer app without changing authentication, matching, or
> the existing audit/revert path in a breaking way.
> **Repo:** `C:\Users\Xander\Desktop\PalTuro\palturo`
> **Admin repo:** `C:\Users\Xander\Desktop\PalTuro\palturo-admin`
> **Supabase project:** `yjcrfgvenilptrnudvcb`
> **Production:** live.

This file is the source of truth for a fresh session. Update the status and
changelog as work lands.

## Implementation record (2026-11-20)

- Migration `20261120001000_account_warnings.sql` applied: table, counter
  trigger, issue/get/acknowledge/revoke RPCs, `notifications` kind constraint,
  and visibility filtering in `list_notifications` +
  `count_unread_notifications`.
- `admin_issue_warning` records the warning and inserts the
  `account_warning` notification atomically. The trigger maintains
  `profiles.warning_count` and `last_warned_at` from retained warnings.
- `admin-api` warn resolution accepts `warning_category`, `warning_days`
  (1–365), and `warning_message`; audit revert now revokes the warning instead
  of restoring a stale counter. `users.detail` returns warning history.
- Admin console: warn dialog has category, visibility duration, and required
  user message; user detail lists retained warnings with visible/hidden/revoked
  state and acknowledgment.
- Flutter: `account_warning` notification kind, Activity “Updates” entry,
  Account standing page, acknowledgment, account-settings link, notification
  bypass for account notices, and local-notification routing.
- Verification: SQL issue/expiry/revoke/client-read checks passed; a live admin
  warn on a test report produced the warning, notification, counter, and audit;
  client RPCs read and acknowledged it; cleanup restored zero. `flutter analyze`
  clean, 320 tests pass, admin typecheck/build and 23/23 production smoke pass.
- Caveat: notifications are sent immediately, so consumers on builds older than
  this change see a generic “Activity” row until they update.
- The consumer web app was still serving the previous bundle when the first
  warning was tested; `tool/deploy_web.ps1` was run after verifying the backend
  record and notification. The new bundle (`palturo.app`, Worker version
  `127c30a4-1a0c-4b55-9922-dee25aa98a97`) contains the Account warning copy,
  Account standing page, and acknowledgment. Native builds still need their own
  release.

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
| Warning expiry | Admin chooses 7/14/30/60/90 days; the user-facing warning disappears at the deadline, the record stays |
| Counter | `profiles.warning_count` counts every retained, non-revoked warning |
| Old clients | Warning notifications are sent immediately; older builds show a generic Activity row until they update |
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
  visible_days integer not null default 30
    check (visible_days between 1 and 365),
  visible_until timestamptz not null,
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

`notify()` already accepts any kind. The migration also updates
`notifications_kind_check` for `account_warning`. To keep the client consistent:

- `list_notifications` hides `account_warning` rows whose warning is revoked or
  past `visible_until`.
- `count_unread_notifications` applies the same filter so the badge cannot count
  an invisible warning.

Notifications are sent immediately when a warning is issued. Warnings are rare,
and older app builds show a neutral generic Activity row until they update.

### 5.5 Migration set

One additive migration: `20261120001000_account_warnings.sql` (table, indexes,
trigger, kind constraint, RPCs, notification filters).

All additive. No column drops, no signature changes to existing RPCs.

---

## 6. Admin console changes

`palturo-admin`:

- **Resolve dialog** (`ModerationPage`): when action is **Warn**, reveal:
  - category select (spam, harassment, irrelevant, other);
  - required “Message to the user” textarea (1–500, pre-filled policy copy,
    editable);
  - internal reason stays the existing field.
- **User detail**: Warning history (visible/hidden/revoked) with message, dates,
  acknowledgment, and internal reason. Revocation is available through audit
  revert; there is no separate revoke button yet.
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

1. **Apply the migration.** Existing behavior is unchanged until a warning is
   issued.
2. **Deploy `admin-api`** with the new optional fields and RPC calls. Old
   console payloads still work.
3. **Deploy admin console** with the warning message/history UI.
4. **Ship the consumer app** and monitor adoption through
   `client_errors.app_version` and store metrics.
5. **Test with an internal account:** admin warns it; the account receives one
   notification, opens Account standing, acknowledges; the admin sees the
   acknowledgment; audit revert or `admin_revoke_warning` removes it and
   decrements the counter.
6. **Watch** for 24–48 hours: notification errors, account-screen errors,
   duplicate warnings, counter drift.
7. Announce the policy to moderators.

### Why delivery starts immediately

Warnings are rare and time-sensitive. Older app builds map `account_warning` to
`unknown`, which shows a neutral Activity row rather than breaking, so there is
no destructive behavior while users update. The detail view is available as soon
as the new build lands.

---

## 9. Regression guards

- No changes to `profiles` columns, auth bans, matching, or existing RPC
  signatures.
- No new grants on `profiles` or `notifications`.
- `list_notifications` only gained a filter for `account_warning`; existing
  kinds are untouched. `count_unread_notifications` mirrors it.
- Audit revert remains the only mutation path for resolved reports; its warning
  branch is additive.
- Existing notification kinds, filters, and preferences unchanged.
- New table is service-only; no RLS policy widening.
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

- Revoke warnings via `admin_revoke_warning`; the trigger restores counters and
  the notification disappears from the client.
- Hide the feature by leaving warnings unissued; the table and RPCs are harmless
  if unused.
- The admin console can keep the history UI reading the table.
- Existing report resolution still works without a warning message (defaults).

---

## 12. Open questions

1. Should a third active warning auto-suspend? (Recommend: no, keep human
   review; revisit after data.)
2. Should the visibility window be per-warning? (Implemented: per warning,
   7–90 days; expand to custom values if needed.)
3. Should the user be able to appeal from the warning card? (Recommend: link to
   Support, no formal workflow.)
4. Should the notification survive the user disabling “Activity updates”?
   (Implemented: yes, it is an account notice.)
5. Do we need email for users who never open the app? (Out of scope; push +
   in-app first.)

---

## 13. Changelog

- 2026-11-20 — Plan created. Current warning path audited; no user-facing
  warning existed.
- 2026-11-20 — Implemented: `account_warnings`, visibility window, counter
  trigger, notification kind, admin duration/message fields, consumer Account
  standing and acknowledgment, expiry-aware list/badge filters. Verified with a
  live admin warning and client RPC read/ack/revoke.
