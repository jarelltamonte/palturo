# PalTuro visual fix plan — V-01 to V-08

**Branch:** `ui-features`
**Base:** `b121126` (after deck rebuild, chrome pass, auth web move)
**Source audit:** `docs/PalTuro-Visual-Audit-2026-11-05.pdf` (5 Nov 2026)
**Owner:** PalTuro engineering
**Status:** COMPLETE — all eight fixes passed their gates.

## 1. Objective

Close every finding in the visual audit without regressing the shipped flows
(onboarding, deck, chat, requests, profile, settings, auth). Each fix is small,
traceable to one audit ID, and gated by three independent audits.

## 2. Non-negotiables

- Work stays on `ui-features`; no new polish branch.
- No push unless explicitly requested.
- One commit per fix, referencing `VF-xx` and `V-xx`.
- A fix is not "done" until functionality, quality, and regression audits all
  return **PASS**. A FAIL blocks the next fix.
- Analyze clean and the full test suite green before every audit gate.
- Use existing tokens (`AppSpacing`, `AppChrome`, `AppTextStyles`) before new
  values. Any new token is documented here.

## 3. Traceability matrix

| Fix | Audit | Finding | Primary files | Acceptance | Status |
|---|---|---|---|---|---|
| VF-01 | V-01 | Role cards stretch to full page height | `onboarding/widgets/role_card_group.dart`, `onboarding_scaffold.dart` | Cards ≤ 200 px tall at 390×844; three cards visible; group centred; Continue unchanged | **DONE** |
| VF-02 | V-02 | Home skeleton for 10–12 s with no fallback | `screen/home_page.dart`, `widgets/person_card_skeleton.dart` | Skeleton shows progress copy after 4 s; Retry available; request capped at 12 s; cached deck paints immediately | **DONE** |
| VF-03 | V-03 | Empty states at three different heights | new `widgets/app_empty_state.dart`, `chats_page.dart`, `request_page.dart`, `notifications_page.dart` | One widget, one inset, one action slot; centres within ±12 px; Activity has an illustration | **DONE** |
| VF-04 | V-04 | Profile name wraps; empty skill cards | `screen/profile_page.dart`, `screen/card/skills_card.dart` | Name clamps to 1 line; avatar 72 px; Edit stays top-right; empty skills show "Add skills" | **DONE** |
| VF-05 | V-05 | Trailing icons drift 2 px and 44/48 px | `screen/home_page.dart`, other trailing actions | Every trailing action uses 48 px; rightmost centre = 350 px at 390 width | **DONE** |
| VF-06 | V-06 | Browse content runs under bottom nav | `screen/explore_page.dart`, `theme/app_spacing.dart` | Bottom padding ≥ nav + 16 px; last row fully clears the nav; no double gap | **DONE** |
| VF-07 | V-07 | Notification settings end with no bottom inset | `screen/settings/notification_preferences_page.dart` | Shared pushed-page bottom inset; scroll end has breathing room; no clipped section header at rest | **DONE** |
| VF-08 | V-08 | Copy/media polish | `screen/utils/pals_count.dart`, `onboarding/*`, `screen/card/person_card.dart` | "0 Pals"; en dash in step labels; media focal alignment documented; no new crop regressions | **DONE** |

## 4. Audit protocol (per fix)

Run after the fix is implemented and locally green.

1. **Functionality audit** — read-only. Checks the acceptance criteria against
   the code path and existing/new tests. Returns PASS/FAIL and any behavioral
   gaps.
2. **Quality audit** — read-only. Checks token usage, duplication, semantics,
   accessibility (48 px targets, labels), dark/light, text scaling, and
   formatting. Returns PASS/FAIL.
3. **Regression audit** — runs `flutter analyze --no-pub` and
   `flutter test --no-pub`, then checks adjacent screens and public APIs.
   Returns PASS/FAIL with the exact failing test names.

Rules:
- All three must PASS. Any FAIL is fixed and all three re-run.
- Record the audit results in the ledger with date, verdicts, and the commit.
- No fix is committed until its gate is green.

## 5. Progress ledger

| Fix | Implemented | Analyze | Tests | Func | Quality | Regr | Commit | Evidence |
|---|---|---|---|---|---|---|---|---|
| VF-01 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `9a60a2a` | 163 tests; 168 px cards; 640×411 @200% scrolls |
| VF-02 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `2cf6cde` | 166 tests; 4s/12s states; retry + stale-load test |
| VF-03 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `f2b1ae2` | 169 tests; shared widget; 200% nav clearance |
| VF-04 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `d6c68bf` | 172 tests; clamp/72 pinned; empty CTA semantics |
| VF-05 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `dc12bed` | 174 tests; 48 px targets; centre 350 |
| VF-06 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `f347172` | 175 tests; nav+16 clearance; 36-combo sweep |
| VF-07 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `9629f56` | 176 tests; safe-area inset; 48 icon |
| VF-08 | ☑ | ☑ | ☑ | PASS | PASS | PASS | `5a18e7a` | 177 tests; Pals/en dash/media focused |

## 6. Sequencing and rationale

1. **VF-01** — first screen after login; highest visible severity, smallest
   change.
2. **VF-02** — first-run trust; needs a state machine, so it follows the layout
   fix.
3. **VF-03** — one shared component; unlocks Activity and keeps VF-07 honest.
4. **VF-04** — profile header; independent of the deck.
5. **VF-05** — chrome normalisation; after profile so the right-side baseline is
   final.
6. **VF-06** — Browse inset; depends on the nav height token.
7. **VF-07** — settings inset; shares the VF-06 token.
8. **VF-08** — copy/media last so screenshots in the report are stable.

## 7. Verification per fix

| Fix | Automated | Visual |
|---|---|---|
| VF-01 | widget test: card height ≤ 200, 3 cards, semantics intact | 390×844 light/dark |
| VF-02 | widget test: 4 s slow state, 12 s timeout, retry | 390 skeleton → deck |
| VF-03 | widget test: shared widget used by 3 screens | 390 Chats/Requests/Activity |
| VF-04 | widget test: 1-line clamp, avatar 72, Add skills | 390 long name |
| VF-05 | widget test: action size 48, centre 350 | 390 all tabs |
| VF-06 | widget test: bottom padding ≥ 96 | 390 Browse scrolled to end |
| VF-07 | widget test: bottom inset 32 | 390 Notifications scrolled to end |
| VF-08 | unit test: pals copy; goldens not required | 390 Profile + deck |

## 8. Environment

- Flutter 3.47.6 / Dart 3.13.5 on Windows.
- `flutter analyze --no-pub`
- `flutter test --no-pub`
- Web build: `flutter run -d web-server --web-port 5317`
- Playwright capture: 390×844 @2x and 1440×900.

## 9. Change log

| Date | Fix | Result | Commit |
|---|---|---|---|
| 2026-11-05 | plan created | — | — |
| 2026-11-05 | VF-01 | PASS after 3 gate rounds (fixed scroll clipping + short/200% coverage) | `9a60a2a` |
| 2026-11-05 | VF-02 | PASS after 2 gate rounds (fixed stale-load timer clobbering) | `2cf6cde` |
| 2026-11-05 | VF-03 | PASS after 4 gate rounds (fixed nav clearance + sliver intrinsics) | `f2b1ae2` |
| 2026-11-05 | VF-04 | PASS after 3 gate rounds (fixed semantics + 200% test) | `d6c68bf` |
| 2026-11-05 | VF-05 | PASS after 9 gate rounds (fixed iOS clamp + chat header scaling) | `dc12bed` |
| 2026-11-05 | VF-06 | PASS after 4 gate rounds (fixed double-counted nav inset) | `f347172` |
| 2026-11-05 | VF-07 | PASS after 3 gate rounds (safe area + 48 icon) | `9629f56` |
| 2026-11-05 | VF-08 | PASS after 2 gate rounds (complete en dash + video alignment) | `5a18e7a` |
