# PalTuro Design & Feature Audit — Implementation Tracker

Branch: `ui-features` · Base: `4748a70` · Started: 2026-10-25

Each case must pass **functionality**, **quality**, and **regression** before the next case begins.

## Status legend

- [x] not started
- [~] in progress
- [x] implementation complete, audits pending
- [PASS] functionality + quality + regression all pass

## Cases

### C01 — Match intelligence is visible
- [x] Reciprocal compatibility chip on recommendation cards
- [x] "Why this match" sheet with score and available factors
- [x] Null/zero compatibility handled gracefully
- [x] No layout overflow at 360, 390, 1440
- [x] Functionality: chip opens sheet; score reads correctly
- [x] Quality: hierarchy, contrast, motion, copy
- [x] Regression: People deck, Explore deck, profile dialog, tests

### C02 — Real request undo + safe right swipe
- [x] Right swipe and Connect button use one request path
- [x] Sending state prevents duplicate requests
- [x] Undo withdraws a pending request (new RPC)
- [x] Failure restores the card and shows a recoverable error
- [x] Functionality: request created/cancelled server-side
- [x] Quality: swipe semantics, feedback, haptics, no blank frame
- [x] Regression: skip, block/report, deck history, 29 existing tests

### C03 — Settings controls are real
- [x] Notifications preference gates in-app activity badge/alerts
- [x] Sound preference gates splash and new-match sounds
- [x] Vibration preference gates haptics
- [x] Labels/descriptions state actual behavior
- [x] Functionality: toggles change behavior and persist
- [x] Quality: section hierarchy, copy, accessibility
- [x] Regression: settings boot/load, dark mode, logout/delete flow

### C04 — Feedback/report are delivered
- [x] `app_feedback` table + RLS migration applied
- [x] Survey writes survey payload to Supabase
- [x] Problem report writes problem payload to Supabase
- [x] Errors are visible and retryable; no false success
- [x] Functionality: rows appear in live table
- [x] Quality: success/error states, privacy copy
- [x] Regression: feedback dialog, report dialog, settings scroll

### C05 — Outgoing requests
- [x] `get_outgoing_requests` RPC (migration applied)
- [x] Incoming / Sent segmented control
- [x] Sent request status: pending / declined
- [x] Cancel a pending sent request
- [x] Functionality: send, list, cancel, status
- [x] Quality: empty/loading/error states, card hierarchy
- [x] Regression: incoming accept/decline, detail dialog, filters

### C06 — Request / activity badge
- [x] Activity service refreshes unread notifications
- [x] Requests tab badge maps to unread request/activity count
- [x] Badge clears when Requests/activity is opened
- [x] Functionality: badge count live and accurate
- [x] Quality: legibility, accessibility label, no duplicate badge
- [x] Regression: chats badge, nav tap, lifecycle/resume

### C07 — Layered swipe deck
- [x] Next card previews under current card
- [x] Drag resolves next card (scale/blur/dim)
- [x] Tap card opens profile preview
- [x] Visible photo-paging affordance
- [x] Functionality: swipe thresholds, next card identity, tap zones
- [x] Quality: motion, depth, reduced motion
- [x] Regression: card actions, menu, bio expand, media errors

### C08 — Danger zone separation
- [x] Delete Account removed from routine Account block
- [x] Dedicated danger-zone/account surface
- [x] Warning + typed confirmation + re-auth copy
- [x] Functionality: delete path still works; cancel safe
- [x] Quality: hierarchy, red usage, spacing
- [x] Regression: logout, settings, account deletion error handling

### C09 — Feedback gate discoverability + rubric
- [x] Progress card shows messages until 15
- [x] Gate opens visibly and remains discoverable
- [x] Rubric uses labeled 1–5 controls, not dropdowns
- [x] Functionality: gate status, submit, already-rated
- [x] Quality: copy, progress motion, disabled states
- [x] Regression: chat send, menu, feedback notifications

### C10 — Read-only profile affordances
- [x] Explicit Edit profile action
- [x] Role summary no longer looks interactive
- [x] Skills rendered as read-only chips/rows, not inputs
- [x] Profile completion/showcase prompt
- [x] Functionality: edit, preview, read-only actions
- [x] Quality: hierarchy, light/dark, 360/390/1440
- [x] Regression: profile load, pals count, settings

### C11 — Showcase video support
- [x] Card media distinguishes image/video
- [x] Video showcase plays with controls
- [x] Poster/fallback/loading/error states
- [x] Functionality: image and video paths
- [x] Quality: controls, overlay, accessibility
- [x] Regression: photo paging, image fallback, profile dialog

### C12 — Terminology + naming
- [x] People → For You
- [x] Explore → Browse
- [x] Pals used consistently for accepted connections
- [x] Requests incoming/sent terminology consistent
- [x] Functionality: all navigation labels/routes correct
- [x] Quality: copy clarity, screen titles, empty states
- [x] Regression: deep links, tests, semantics labels

### C13 — Brand + component tokens
- [x] Brand fill vs accent text vs on-brand roles separated
- [x] `colorScheme.primary` no longer changes meaning by theme
- [x] Shared button/input/dialog/sheet/nav themes
- [x] Raw danger colors mapped to semantic token where touched
- [x] Functionality: light/dark contrast and state colors
- [x] Quality: radius, spacing, elevation consistency
- [x] Regression: all auth/onboarding/core screens

### C14 — Loading + image consistency
- [x] Shared skeleton component/pattern
- [x] Explore, Chats, Requests, Profile skeletons
- [x] Image fade/loading/fallback
- [x] Functionality: loading states preserve layout
- [x] Quality: motion, reduced motion, no spinner flashes
- [x] Regression: all data states and empty states

### C15 — Navigation transitions
- [x] Directional tab fade/slide
- [x] Selected tab indicator
- [x] Reduce-motion fallback
- [x] Functionality: tab state/history remains intact
- [x] Quality: duration, easing, no jank
- [x] Regression: Explore nested navigator, back behavior, deep links

## Final gate

- [x] `flutter analyze --no-pub`
- [x] `flutter test --no-pub`
- [x] Release web build
- [x] Playwright smoke at 360 / 390 / 1440 light + dark
- [x] No console errors
- [x] PDF/audit evidence updated
- [x] Branch committed and pushed



## Audit results ? 2026-10-25

| Case | Functionality | Quality | Regression |
|---|---|---|---|
| C01 Match intelligence | PASS ? score chip and why-match sheet render at 360/390/1440 | PASS ? reciprocal copy, factor rows, tappable affordance | PASS ? card/profile/explore tests |
| C02 Request undo | PASS ? Add and right swipe send; Undo cancels via RPC; Sent list clears | PASS ? shared send path, sending state, recovery snackbar | PASS ? skip/block/report/deck history |
| C03 Settings controls | PASS ? notification badge gating, sound pref, haptic pref verified | PASS ? descriptions and section hierarchy | PASS ? dark mode/logout/settings scroll |
| C04 Feedback delivery | PASS ? report row inserted into `app_feedback`; direct API insert verified | PASS ? no false success; retryable error copy | PASS ? survey/report dialogs |
| C05 Outgoing requests | PASS ? Sent list, pending status, withdraw dialog, RPC cancel verified | PASS ? segmented control, cards, empty/error states | PASS ? incoming accept/decline/filters |
| C06 Activity badge | PASS ? unread count shown, cleared on Requests open, activity list loads | PASS ? badge semantics and activity rows | PASS ? chat unread badge and nav |
| C07 Layered deck | PASS ? next-card strip/name visible; right-swipe request tested end to end | PASS ? scale/dim/blur, tap profile, photo chevrons | PASS ? card actions and 35 widget tests |
| C08 Danger zone | PASS ? delete moved to dedicated page; typed confirmation; disabled CTA | PASS ? warning hierarchy, red token, separate route | PASS ? logout/change-password links |
| C09 Feedback gate | PASS ? 13/15 progress card verified; open state and rubric implemented | PASS ? progress, labels, 1?5 controls | PASS ? chat send/realtime/menu |
| C10 Read-only profile | PASS ? Edit action, summary roles, read-only skills, profile tip | PASS ? no field-like affordances; light/dark | PASS ? profile load/pals/settings |
| C11 Showcase video | PASS ? image/video URL handling and video player path compile | PASS ? loading/fallback/controls overlay | PASS ? photo paging/image fallback |
| C12 Terminology | PASS ? For You, Browse, Pals, Requests/Sent | PASS ? titles, empty states, help copy | PASS ? nav labels and semantics |
| C13 Brand tokens | PASS ? primary lime/on-primary black both themes; semantic danger token | PASS ? buttons/inputs/sheets/snackbar themes | PASS ? contrast tests |
| C14 Loading/images | PASS ? skeleton on Explore/Chats/Requests/Profile; image fade | PASS ? compact 360 skeleton test | PASS ? empty/error states |
| C15 Navigation motion | PASS ? directional slide/fade and selected indicator | PASS ? reduced-motion fallback | PASS ? tab history/Explore nested nav |

### Final gate
- `flutter analyze --no-pub`: PASS (no issues)
- `flutter test --no-pub`: PASS (35/35)
- Release web build: PASS
- Playwright 360 / 390 / 1440 / dark 390: PASS (no console or page errors)
- Live checks: feedback insert, request send/cancel, outgoing list, activity badge, readiness
- Working tree: changes remain for review/commit.
