# PalTuro — Design & Feature Audit v2
## Action, recommendation, and design specification

**Branch:** `ui-features @ 3cd767c`  
**Date:** 25 October 2026  
**Baseline:** 15/15 implementation cases PASS · 37 tests · release web build verified  
**Companion PDF:** `PalTuro-Design-Feature-Audit-v2-2026-10-25.pdf`  
**Purpose:** turn the remaining v2 audit findings into implementable product and UI instructions without reopening work that is already shipped.

---

## 0. How to use this document

This file is the implementation companion to the v2 audit. It is written for design, Flutter, QA, and backend work.

Each case contains:

1. **Status and priority**
2. **Problem and user impact**
3. **Current evidence**
4. **Target experience**
5. **Design specification** — layout, components, copy, states
6. **Implementation notes** — source files and data contracts
7. **Accessibility requirements**
8. **Acceptance criteria**
9. **Recommended tests**
10. **Dependencies / guardrails**

### Status key

| Status | Meaning |
|---|---|
| **SHIPPED** | Implemented and accepted in the 15-case baseline. Do not reimplement. |
| **PARTIAL** | A surface exists, but its workflow, state model, or depth is incomplete. |
| **MISSING** | No destination, control, or data surface exists. |
| **NEW GAP** | Found after the implementation pass; outside the original 15 cases. |

### Priority key

| Priority | Meaning |
|---|---|
| **P1** | Structural trust or comprehension gap. Fix before calling the UI complete. |
| **P2** | Product consistency, completeness, or accessibility gap. Fix in the same UI cycle. |
| **P3** | Polish, scale, or future opportunity. |

### Non-negotiable guardrails

- Preserve the charcoal/lime identity, Comfortaa + Inter, rounded cards, floating navigation, and swipe deck.
- Do not add a sixth tab. Account, Browse, and Activity fit inside the existing five-tab model.
- Do not regress the 15 shipped cases. See Section 1.
- Do not present a success message for work that did not reach its destination.
- Use semantic color/state tokens. Do not hard-code `Colors.white`, `Colors.black`, or raw danger colors for text without checking the theme.
- Every tappable element must have a ≥44×44 target and a meaningful semantic label.
- Every screen must have default, loading, empty, error, and dark states where applicable.

---

### Case index

| Case | Title | Status | Priority |
|---|---|---|---|
| 01 | Settings and Account hierarchy | MISSING | P1 |
| 02 | Browse depth and taxonomy | MISSING | P1 |
| 03 | Category card context | PARTIAL | P1 |
| 04 | Edit Profile structure and role safety | PARTIAL | P1 |
| 05 | Dark-mode edges | NEW GAP | P1 |
| 06 | Activity destination | PARTIAL | P1 |
| 07 | Chat state model | PARTIAL | P2 |
| 08 | Pals integrity | PARTIAL | P2 |
| 09 | Requests after accept | PARTIAL | P2 |
| 10 | Onboarding durability | PARTIAL | P2 |
| 11 | Copy and routing clarity | NEW GAP | P2 |
| 12 | System consistency | PARTIAL | P2 |
| 13 | Feedback survey navigation | PARTIAL | P2 |
| 14 | Auth and accessibility polish | PARTIAL | P2 |

---

## 1. Shipped baseline — do not reopen

These are the accepted 15 cases. The only reason to revisit them is a regression caused by new work, or the specific residual called out in the right column. Do not put them back in the “missing” backlog.

| # | Case | Accepted behavior | Residual outside the case |
|---|---|---|---|
| C01 | Match intelligence | Compatibility chip, clamped score, why-match sheet, basic-mode disclosure | None |
| C02 | Request undo | Single send path, sending state, backend withdrawal, scoped Undo, card restore on failure | None |
| C03 | Settings controls | Notification/sound/vibration behavior and persistence | Settings grouping and Account IA are separate; Cases 01 and 11 |
| C04 | Feedback delivery | Survey/problem report insert to Supabase, RLS, privacy copy, busy guards | Survey navigation is Case 13 |
| C05 | Outgoing requests | Incoming/Sent, pending/declined, withdrawal, tab refresh | Sent filters and accepted history are Case 09 |
| C06 | Activity badge | Auth-scoped unread count, Requests badge, list, mark-read | Deep links, per-item read, and pre-load behavior are Case 06 |
| C07 | Layered deck | Next-card peek, drag resolution, profile tap, photo affordances | Browse category deck has not adopted it; Case 03 |
| C08 | Danger zone | Dedicated delete page, warning, typed confirmation, busy lock | Re-auth and account grouping are Cases 01/14 |
| C09 | Feedback gate | Progress, unlock, submitted state, labeled rubric | Survey Back/Skip is Case 13 |
| C10 | Read-only profile | Explicit Edit, read-only role/skills, completion prompt | Showcase/public preview are Case 04 |
| C11 | Showcase media | Image/video display, controls, fallback | Upload/edit and required showcase are Case 04 |
| C12 | Terminology | For You, Browse, Pals, Incoming/Sent | Copy clean-up is Case 11 |
| C13 | Design tokens | Brand fill/accent/on-brand, component themes, danger text | Two specific dark surfaces are Case 05 |
| C14 | Loading/images | Skeletons on four main tabs, image fade/fallback | Other route loaders are Case 12 |
| C15 | Navigation motion | Directional slide/fade, selected indicator, reduced motion, focus exclusion | None |

### Residual rule

A residual is not a failed case. Example:

- C06’s badge is accepted; Activity’s **destination quality** is a different surface.
- C11’s video **display** is accepted; upload/edit was explicitly outside scope.
- C08’s dedicated page is accepted; **account architecture and re-auth** were not part of the case.

---

## 2. Global design system for the remaining work

These rules apply across all cases.

### 2.1 Information architecture

Use one job per section:

```
Settings
├─ Preferences
├─ Account & security
├─ Support
└─ Legal & about
```

```
Profile
├─ identity summary
├─ Pals
├─ role
├─ skills to learn
├─ skills to teach
├─ completion / showcase prompt
└─ account entry
```

```
Browse
├─ root categories
├─ category detail
│  ├─ child categories / skill chips
│  ├─ count and role context
│  └─ people list/deck
└─ person profile
```

### 2.2 Layout scale

Use an 8-point rhythm where possible:

| Token | Value | Use |
|---|---:|---|
| `space.xs` | 4 | icon gap, chip inner |
| `space.sm` | 8 | row gap |
| `space.md` | 12 | card inner gap |
| `space.lg` | 16 | page padding, section gap |
| `space.xl` | 24 | section separation |
| `space.2xl` | 32 | major block separation |

### 2.3 Radius scale

| Token | Value | Use |
|---|---:|---|
| `radius.sm` | 12 | chips, inputs |
| `radius.md` | 20 | cards, dialogs |
| `radius.lg` | 24 | main cards, sheets |
| `radius.xl` | 28 | person cards, large sheets |
| `radius.pill` | 999 | segmented controls, tags |

Do not introduce another arbitrary radius unless the surface is intentionally distinctive.

### 2.4 Typography

| Role | Style |
|---|---|
| Page title | Inter Bold, 24–28 pt depending on hierarchy |
| Subpage title | Inter Bold, 20 pt |
| Section heading | Inter Bold, 14–16 pt |
| Body | Inter Regular, 14–16 pt |
| Supporting | Inter Regular, 12–13 pt |
| Metadata | Inter Regular, 11–12 pt |
| Brand moment | Comfortaa, used sparingly |

Use a single page-title scale:

- Main tabs: 24 pt.
- Pushed subpages: 20 pt.
- Blocked Users currently sits at 16 pt; promote it to 20 pt.

### 2.5 Status and feedback

- **Loading:** skeleton for structured lists/grids; spinner only for short modal/transaction work.
- **Empty:** one sentence of cause + one action when an action exists.
- **Error:** say what failed and provide Retry; do not say “check your connection” for a server validation error.
- **Success:** only after the server confirms.
- **Destructive:** red foreground token, confirmation, explicit verb (“Delete”, “Withdraw”, “Discard”).
- **Disabled:** visibly disabled and semantically disabled.

### 2.6 Copy principles

- Use the product’s nouns consistently: **For You**, **Browse**, **Pals**, **Requests**, **Chats**.
- Prefer verbs over vague nouns: “Send request”, not “Add”; “Discard changes”, not “OK”.
- Do not expose implementation terms to users (`basic_bi`, `pipeline`, `hasUnread`).
- Do not use negative placeholders when omission is better. “No learning styles set” becomes “Learning style not specified” or is hidden.
- Pluralize counts.
- Every dead-end promise must either gain a destination or lose its copy.

### 2.7 Accessibility baseline

- Tap targets ≥44×44.
- All custom gestures have `Semantics(button: true, label: ...)`.
- Selection controls expose `selected: true/false`.
- Do not use color alone for selected/unread/danger.
- Test 200% text on the card, Edit Profile, Settings, and chat header.
- Keyboard focus must be visible and ordered on web.

---

# Part A — Structural cases (P1)

---

## Case 01 — Settings and Account hierarchy

**Status:** MISSING  
**Priority:** P1  
**PDF reference:** pages 12–13

### Problem

Settings is a single long column that mixes four different mental models:

1. Preferences
2. Support
3. Safety/privacy
4. Account/security

Blocked Users sits between Preferences and Account with no heading. There is no account identity, no privacy/legal destination, and no session management. Delete Account is still a top-level Settings block.

### User impact

A user cannot answer “Where do I change my password?”, “Where is my email?”, “Where are my blocked users?”, or “How do I delete my account?” without scanning an undifferentiated list. Destructive controls sit too close to routine settings.

### Current evidence

`lib/screen/settings.dart`

- Preferences: notifications, sound, vibration, dark mode.
- Unlabeled middle group: Send Feedback, Report a Problem, Blocked Users.
- Account: Change password, Log Out.
- Danger zone: Delete account.

### Target experience

A user understands the Settings root in one scan. Account identity is visible through a dedicated row. Every advanced account action lives one level deeper.

### Design specification

#### Settings root

```
Settings
┌────────────────────────────────────┐
│ PREFERENCES                        │
│ Notifications              [toggle]│
│ Sound                      [toggle]│
│ Vibration                  [toggle]│
│ Dark Mode                  [toggle]│
├────────────────────────────────────┤
│ ACCOUNT & SECURITY                 │
│ [avatar] Aling Rosa                │
│          aling@example.com      >  │
├────────────────────────────────────┤
│ SUPPORT                            │
│ Send feedback                   >  │
│ Report a problem                >  │
│ Help & contact support          >  │
├────────────────────────────────────┤
│ LEGAL & ABOUT                      │
│ Terms of Service                >  │
│ Data Policy                     >  │
│ Cookies Policy                  >  │
│ Version 0.1.0                   >  │
└────────────────────────────────────┘
```

**Rules**

- Do not show Delete Account on the Settings root.
- Do not put Blocked Users under Preferences.
- Account row should show avatar, display name, email, and a chevron.
- Support and Legal should be separate section headings, not just dividers.
- Log Out belongs inside Account & Security, below security rows and above danger.

#### Account & Security page

```
Account & security

[avatar] Aling Rosa Reyes
         aling@example.com   [Verified]

IDENTITY
Email                     aling@example.com  >
Display name              Aling Rosa         >

SECURITY
Password                  Change             >
Active sessions           2 devices          >
Sign out all devices                         >

PRIVACY
Blocked users             3 people           >
Data & privacy                               >

DANGER ZONE
Delete account            Permanently remove profile, Pals, chats
```

**Rules**

- Email is read-only unless an email-change flow exists.
- Display name should be editable here or in Edit Profile, not both with different behavior.
- Active sessions may be a static row until Supabase session enumeration is implemented.
- Delete account opens the dedicated DeleteAccountPage; it does not delete from a list row.
- Danger zone is visually separated, at the bottom, with a red foreground token.

### Implementation notes

- New route: `lib/screen/account/account_settings_page.dart`.
- Optional support route: `lib/screen/account/support_page.dart`.
- Optional legal route: `lib/screen/account/legal_page.dart`.
- Reuse `LegalDialogs` content; do not duplicate legal copy.
- Settings root pushes the account page rather than embedding account rows.
- Reuse `UserAvatar` and `AppColors`.
- If active sessions cannot be enumerated, show “Manage sessions” with a supported explanation rather than fake numbers.

### States

- No email: show “Not set” with an action if the flow exists.
- No blocked users: “No blocked users” with Help copy.
- Session backend unavailable: show “Session management is not available yet” and keep Sign out all available only if supported.
- Delete failure: keep the user on the page, show a retryable error, do not sign out.

### Accessibility

- Account row is a button with a combined label: “Account and security, Aling Rosa, aling@example.com.”
- Section headings are exposed as headings in semantics.
- Toggle rows keep the whole row tappable.
- Danger row is a button, not just red text.

### Acceptance criteria

- [ ] Settings has four visible groups: Preferences, Account & Security, Support, Legal & About.
- [ ] Account identity is visible without opening a subpage.
- [ ] Blocked Users is no longer in the Preferences group.
- [ ] Legal/Support are reachable from Settings.
- [ ] Delete Account is not on the Settings root.
- [ ] Log Out is in Account & Security, not Preferences.
- [ ] Every row has one clear destination.
- [ ] No new tab is added.

### Tests

- Widget test: Settings root groups.
- Widget test: Account row opens Account & Security.
- Widget test: Delete is absent from root and present in Account.
- Manual: light/dark, 360/390/1440, 200% text.

### Dependencies / guardrails

- Do not change the behavior of C03 toggles.
- Do not move Delete Account back into the routine account block.
- Do not create a second legal source; reuse the existing dialogs.

---

## Case 02 — Browse depth and taxonomy

**Status:** MISSING  
**Priority:** P1  
**PDF reference:** page 8

### Problem

Browse is a flat grid of root categories. Tapping a category jumps directly to a single-card deck. The backend taxonomy supports depth and node visibility, but the UI never uses it. There are no counts, search, child skills, breadcrumbs, or role memory.

### User impact

The user can choose a broad category, but cannot browse within it. “Cooking & Culinary” is treated as a single leaf, even though the taxonomy contains specific skills beneath it. Browse does not feel like a browsing tool; it feels like a second recommendation deck.

### Current evidence

- `lib/screen/explore_page.dart:127-139` pushes `ExploreExpand` directly.
- `taxonomy_visible(rootPath)` exists but is only called without a root path.
- `lib/screen/explore_expand.dart` renders one deck and no hierarchy.
- Role defaults to Learner every time; `TODO` remains at `explore_page.dart:25`.

### Target experience

Root → category detail → people. A user can see what is inside a category before meeting people, and can narrow the category without guessing.

### Design specification

#### Browse root

Keep the current grid, but add:

- Category count if available.
- A short section caption: “Explore skills outside your personalized deck.”
- A role toggle that persists the last choice.
- A help icon with the existing “How Browse works” sheet.

#### Category detail — new screen

```
← Cooking & Culinary
  58 people teaching · 12 learning

  Recipes, flavors, and kitchen traditions

  [All] [Baking] [Main dishes] [Preserves] [Regional]

  [Search skills or people................]

  People teaching this skill
  ┌──────────────────────────────────┐
  │ [avatar] Name              [why] │
  │ Skill · Availability · Language  │
  │ Learning style                    │
  └──────────────────────────────────┘

  [Start browsing]  or  [List view]
```

**Rules**

- The category header shows role context and counts.
- Child taxonomy nodes render as chips; if the node is a leaf, skip the chip row.
- Counts should distinguish teaching/learning.
- Search can be local to the selected category at first.
- Provide a list view for users who do not want to swipe.
- “Start browsing” opens the existing card deck with category context preserved.

#### Category data

- Call `taxonomyVisible(rootPath: nodePath)` for children.
- Do not show empty child categories unless they have people or are intentionally visible.
- Counts should come from a server count, not `usage_count` alone; `usage_count` is taxonomy usage, not necessarily people.
- Keep a cached category path so back returns to the detail screen, not the root.

#### Role memory

- Add `browse_role` preference or derive from profile role.
- The toggle should not reset to Learner on every entry.
- If the selected role has no categories, show the empty CTA “Update your teaching skills” and a button to Edit Profile.

### States

- Root loading: existing skeleton.
- Root empty: “No categories available” + Retry.
- Category detail loading: skeleton for header, chips, and rows.
- Category detail empty: “No people in this category yet” + “Browse another category”.
- Search empty: “No people match this skill” + clear search.
- Mentor no skills: CTA to Edit Profile.
- Error: category-specific error + Retry.

### Accessibility

- Category chips use `Semantics(button: true, selected: ...)`.
- Search field has label and clear action.
- Role toggle has group semantics.
- Counts are text, not color-only.
- Back returns to the exact scroll position on root.

### Acceptance criteria

- [ ] Category tap opens a category detail screen, not directly a deck.
- [ ] Child skills appear when the taxonomy has children.
- [ ] Counts are visible and role-aware.
- [ ] Search exists at least within a category.
- [ ] Role persists across entry.
- [ ] Empty/error/loading states exist.
- [ ] No duplicate root “cards” become dead ends.

### Tests

- Widget: category node with children shows child chips.
- Widget: leaf category skips child row.
- Widget: empty mentor state has Edit Profile CTA.
- Manual: 360/390/1440, dark, keyboard, 200%.

### Dependencies / guardrails

- Do not change For You ranking.
- Do not re-use the old `ExploreExpand` as the category detail screen without adding a header and taxonomy layer.
- Do not fake counts if the backend is unavailable; hide them or label “count unavailable.”

---

## Case 03 — Category card context

**Status:** PARTIAL  
**Priority:** P1  
**PDF reference:** page 9

### Problem

The category deck has less information than For You. It has no profile action, no why-match, no schedule, language, learning style, or skill context. The RPC returns only name, avatar, and note; the card renders negative placeholders.

### User impact

The user enters Browse to explore a category and gets a card that is less decision-ready than the recommendation deck. They cannot inspect the person or understand why they are seeing them.

### Current evidence

- `lib/services/match_api.dart:686-710` builds `Person` with `schedule: ''`, `language: ''`, `learningStyle: ''`, `skillName: ''`.
- `lib/screen/explore_expand.dart` passes `onAdd`, `onSkip`, `onBlock`, `onReport` but no `onOpenProfile` / `onWhyMatch`.
- Screenshot at 390 shows “No learning styles set.”

### Target experience

The category card is context-rich but honest: it shows the category skill and profile facts. If compatibility is not calculated in Browse, it does not pretend to have a score.

### Design specification

#### Card anatomy

```
┌────────────────────────────────────┐
│ [category chip]        [•••]      │
│                                    │
│           media / fallback          │
│                                    │
│ Cooking & Culinary · Mentor        │
│ Aling Rosa Reyes                   │
│ [skill] [availability] [language]  │
│ [learning style]                   │
│ [short note]                       │
│                                    │
│ [View profile]  [•••]              │
│ [Pass]                 [Send request]
└────────────────────────────────────┘
```

**Rules**

- `View profile` is always present.
- If a compatibility score exists, show the why-match chip; if not, omit it rather than showing 0%.
- Use `Pass` and `Send request` instead of `Skip` and `Add`.
- Hide rows with no data; do not render “No learning styles set.”
- Show the category-specific skill at the top of the card when available.
- Use the same photo paging, bio clamp, and menu behavior as For You.
- Preserve the bottom nav.

#### Data additions

Extend `browse_skill_users` to return:

```sql
user_id
name
avatar_url
note
schedule / availability
languages
learning_styles
skill_id
skill_name
skill_path
```

Compatibility is optional. If Browse is intentionally unscored, label the deck “Browse results” and do not show a match percentage.

### States

- No profile data: hide fields, show fallback initials.
- Note missing: omit bio block.
- Video/image error: existing fallback.
- No more people: “You’ve seen everyone in this category” + “Back to categories” + “Browse another.”
- Failed request: restore the card.

### Accessibility

- Card profile action has label “View [name]’s profile.”
- Why-match only has a label when the action exists.
- Card actions are 44px high.
- The card must still be navigable with keyboard/semantics when action buttons are present.

### Acceptance criteria

- [ ] Category cards have profile access.
- [ ] No “No learning styles set” placeholder.
- [ ] Schedule/language/style shown when available.
- [ ] No fake 0% match.
- [ ] Card layout remains stable at 360/390/1440.
- [ ] Category cards use the same interaction language as For You.

### Tests

- Widget: category Person without optional fields hides rows.
- Widget: profile open callback.
- Manual: 390 dark/light.
- Regression: block/report menu still works.

---

## Case 04 — Edit Profile structure and role safety

**Status:** PARTIAL  
**Priority:** P1  
**PDF reference:** page 11

### Problem

Edit Profile is a long, undifferentiated scroll. It contains photos, bio, preferences, role, skills, notes, and proof attachments, but only Bio/Availability/Language have labels. Changing role can silently delete hidden skills. The discard dialog says “OK.” Empty photo slots are white in dark mode. The screen promises a showcase it does not contain.

### User impact

Users can lose work, cannot see the structure of the editor, and cannot tell what a photo or skill row means. The screen feels like a form dump rather than a profile builder.

### Current evidence

- `profile_edit.dart:498-504` clears hidden skill arrays on role save.
- `profile_edit.dart:652-659` starts the page with three unlabeled photo slots.
- `profile_edit.dart:203-211` uses “OK” for discard.
- `profile_edit.dart:1079` hard-codes `Colors.white` for empty photo slots.
- `profile_page.dart:567` promises a showcase.

### Target experience

A user can scan sections, understand what each group changes, and switch role without losing data accidentally.

### Design specification

#### Section map

```
Edit Profile
┌────────────────────────────────────┐
│ PROFILE PHOTOS                     │
│ [main] [photo 2] [photo 3]         │
│ Main photo appears first on cards. │
├────────────────────────────────────┤
│ ABOUT YOU                          │
│ Bio                                │
│ Availability                       │
│ Languages                          │
│ Learning style                     │
├────────────────────────────────────┤
│ ROLE                               │
│ [Learn] [Teach] [Both]             │
│ Changing role hides skills; it     │
│ does not delete them.              │
├────────────────────────────────────┤
│ SKILLS TO LEARN                    │
│ ...                                │
├────────────────────────────────────┤
│ SKILLS TO TEACH                    │
│ ...                                │
│ Showcase media lives here.         │
├────────────────────────────────────┤
│ SHOWCASE                           │
│ Add image/video + title            │
└────────────────────────────────────┘
```

#### Photo section

- Label: “Profile photos.”
- First slot: “Main photo.”
- Helper: “The main photo appears on your profile and cards.”
- Each slot has remove/edit; no white hard-coded background.
- Empty slot uses `AppColors.mutedSurface(context)` or `elevatedSurface`.
- Support reorder later; at minimum mark slot 1.
- Show upload progress/error if save fails.

#### Role safety

Preferred behavior:

- Keep learning and teaching arrays even when the current role hides one side.
- Saving a role change does not delete hidden arrays unless the user explicitly clears them.

If product insists on deletion:

- Show a confirmation before save:
  ```
  Switch to Learn?
  Your teaching skills and notes will be hidden.
  [Keep my teaching skills]  [Hide them]
  ```
- Explain that hidden data can be restored by switching back.

#### Save and discard

- Save button disabled when no changes.
- Dirty state indicated by a dot or “Unsaved changes.”
- Discard dialog:
  ```
  Discard changes?
  Your edits have not been saved.
  [Keep editing] [Discard]
  ```
- Do not use “OK” for a destructive choice.

#### Showcase

The current profile prompt promises a showcase. Choose one:

- **Preferred:** add a Showcase section and data model.
- **Interim:** change the prompt to “Complete your skills or bio” and link to fields that exist.
- **Never:** leave “Add a showcase” pointing to an editor with no showcase.

### States

- Saving: overlay, no double submit.
- Saved: pop with updated profile.
- Save failure: remain on page, preserve fields, show error.
- Image upload failure: keep local preview and show retry.
- Role hidden skills: preserve or confirm.
- No changes: disabled Save.
- Back: discard guard only when dirty.

### Accessibility

- Section headings are semantic headings.
- Photo slots label “Main photo”, “Add second photo”, “Add third photo.”
- Role cards announce selected state.
- Error text is associated with fields.
- 200% text does not clip section headers or chips.

### Acceptance criteria

- [ ] Sections are visible: Photos, About you, Role, Skills, Showcase.
- [ ] Main photo is labeled.
- [ ] Role change does not silently delete hidden skills.
- [ ] Empty photo slots use theme surfaces.
- [ ] Discard dialog uses “Discard” / “Keep editing.”
- [ ] Save disabled when clean.
- [ ] Showcase promise has a real destination or is removed.
- [ ] Public preview is available or explicitly deferred.

### Tests

- Widget: change role and save preserves hidden arrays (or shows confirmation).
- Widget: dirty state toggles Save.
- Widget: unsaved dialog copy.
- Widget: dark photo slot uses theme token.
- Manual: 360/390/1440, 200% text.

### Dependencies / guardrails

- Do not break `ProfileData.copyWith` semantics.
- Do not wipe notes on role save.
- Do not regress profile photo upload.

---

## Case 05 — Dark-mode edges

**Status:** NEW GAP  
**Priority:** P1  
**PDF reference:** pages 11 and 18

### Problem

Two specific dark-mode surfaces fail:

1. Onboarding inactive pagination dots use `AppColors.textSecondary` (charcoal) on a charcoal surface.
2. Edit Profile empty photo slots are hard-coded white.

### User impact

The dark theme looks unfinished at the exact moments where a user is setting up identity or photos. The white slots are visually jarring; the missing dots make the onboarding carousel feel broken.

### Current evidence

- `lib/onboarding_intro.dart:104-105`: inactive dot = `AppColors.textSecondary`.
- `lib/screen/profile_edit.dart:1079`: empty photo container = `Colors.white`.
- Confirmed at 390×844 dark.

### Target experience

Both surfaces use the same semantic surface/muted/accent roles as the rest of the dark theme.

### Design specification

- Inactive onboarding dot: `AppColors.mutedText(context).withValues(alpha: 0.28)` or `border(context)`.
- Active dot: `AppColors.primary`.
- Dot size: 8px inactive, 18×8 active; preserve current animation.
- Photo slot: `AppColors.mutedSurface(context)` or `elevatedSurface(context)`; border `AppColors.primary`.
- Empty icon: `AppColors.mutedText(context)`.
- Photo placeholder should not use pure white in dark.
- Check all `Colors.white` / `Colors.black` uses in new work; use semantic tokens when the element is theme-dependent.

### Acceptance criteria

- [ ] Inactive dots visible in dark at 390 and 360.
- [ ] Empty photo slots use dark surface and remain readable.
- [ ] Light mode unchanged.
- [ ] Contrast ≥3:1 for non-text UI and ≥4.5:1 for text.
- [ ] No raw white/charcoal placeholders in dark.

### Tests

- Golden/widget test for onboarding dark.
- Widget test for photo slot color under dark theme.
- Manual: 390 dark and 360 dark.

---

## Case 06 — Activity destination

**Status:** PARTIAL  
**Priority:** P1  
**PDF reference:** page 16

### Problem

The Activity list is generic. It ignores the notification payload, does not name the person or skill, has no per-item action, and marks the badge read before the list successfully loads.

### User impact

A user sees “New connection request” but cannot tell who sent it or open it. The list feels like a log, not an inbox. A failed load can clear the badge, so the user loses the signal without gaining the content.

### Current evidence

- `lib/screen/notifications_page.dart:48-80` maps any payload to generic copy.
- Rows have no `onTap`.
- `initState` calls `_load()` and `ActivityService.instance.markRead()` independently.
- No per-item unread state.

### Target experience

Activity is a usable inbox: specific, actionable, and honest about read state.

### Design specification

#### Row anatomy

```
┌──────────────────────────────────────┐
│ [icon] New request                   │
│        RJ Castillano wants to        │
│        exchange Barong Embroidery    │
│        “View request”      2m ago    │
└──────────────────────────────────────┘
```

- Title: event type.
- Body: actor + skill/context from payload.
- Optional action: “View request”, “Open chat”, “Leave feedback.”
- Unread marker: lime dot or background tint plus semantic “Unread.”
- Timestamp.
- Empty: “No activity yet” + “Start browsing” or “View requests.”

#### Routing

| Kind | Destination |
|---|---|
| `connection_request` | Requests → Incoming; if unavailable, Activity fallback |
| `request_accepted` | Pals/chat or Requests Sent |
| `request_declined` | Requests Sent |
| `feedback_ready` | Chat room / feedback gate |
| unknown | Stay on Activity with an explanatory snackbar |

#### Read state

- Mark read only after the list successfully loads.
- Prefer per-item mark-read when the row is opened.
- Keep a `mark all read` action if the page-level behavior remains.
- If the network fails, keep the unread badge.

### Data

- Parse `payload` for `name`, `skill`, `connection_id`, `requester_id`, etc.
- Do not display raw JSON.
- Fall back to generic copy only when payload lacks the required fields.
- Add a unit test for each kind.

### Acceptance criteria

- [ ] Each row names the actor and context when available.
- [ ] Rows are tappable and route correctly.
- [ ] Failed load does not clear unread state.
- [ ] Per-item or explicit mark-read behavior is clear.
- [ ] Empty/error/loading states exist.
- [ ] No dead-end row for a deleted request/chat; show a friendly fallback.

### Tests

- Unit: payload presentation for all kinds.
- Widget: tap routes to correct destination.
- Widget: failed load leaves badge intact.
- Manual: stale/deleted entity.

---

## Case 07 — Chat state model

**Status:** PARTIAL  
**Priority:** P2  
**PDF reference:** page 14

### Problem

Chats is visually warm, but its state model is thin:

- Unread is coupled to the notification preference.
- No optimistic send, failed-message retry, read receipts, mute, archive, or mark unread.
- Feedback banner takes permanent vertical space.
- Pals strip and Messages repeat the same people.

### User impact

Turning off notification badges silently changes the meaning of unread filters. Sending feels like waiting for the server. The chat lacks the controls users expect from a messaging surface.

### Current evidence

- `chats_page.dart:81-83`: `hasUnread = notificationsEnabled && c.unread > 0`.
- `chats_room.dart` sends only after server response.
- Feedback progress card is always shown for a connected room.
- Chats shows “Your Pals” strip plus “Messages.”

### Target experience

Unread is data. Badge visibility is a preference. Sending is immediate and recoverable.

### Design specification

#### State separation

- `ChatStateService` owns conversation unread counts.
- `PreferencesService.notificationsEnabled` only controls badge/dot visibility.
- The Unread filter uses conversation unread data, not the preference.

#### Message states

| State | UI |
|---|---|
| Sending | Bubble appears immediately at opacity 0.7 with small spinner |
| Sent | Bubble solid; optional single check |
| Failed | Bubble + red “Not sent” + Retry |
| Read | Optional double check or “Read” label |
| Muted | No badge; row remains normal |
| Archived | Hidden from default list |

Do not show a snackbar as the only failure state; keep the failed bubble.

#### Chat actions

Add to the overflow or row context:

- Mute / unmute
- Archive
- Mark unread
- View profile
- Report
- Block

#### Feedback banner

- Keep the shipped progress card.
- Collapse to a one-line strip after first view or when the user scrolls.
- Do not show the full card before the first message; use a small “Feedback unlocks at 15 messages” line.

#### Pals vs Messages

- Keep “Your Pals” as quick access, but make the distinction explicit.
- Do not show duplicate rows for the same person in both sections if the message list is already visible; either collapse the strip or label it “Quick access.”
- In Chats, search should match name and message; keep.

### Acceptance criteria

- [ ] Turning off notifications does not change unread filter results.
- [ ] Sending shows an immediate bubble.
- [ ] Failed messages can retry.
- [ ] Mute/archive/mark unread exist or are explicitly deferred.
- [ ] Feedback card does not crowd a new chat.
- [ ] Pals strip and Messages have a clear distinction.
- [ ] No regression to realtime stream/send.

### Tests

- Widget: unread filter independent of preference.
- Widget: optimistic bubble and retry.
- Integration: send failure/recovery.
- Manual: dark, long message, keyboard.

---

## Case 08 — Pals integrity

**Status:** PARTIAL  
**Priority:** P2  
**PDF reference:** pages 10 and 15

### Problem

Pals count is loaded once on Profile and can remain stale after unmatch/block. Chats, Pals, and Profile use different data sources. Singular grammar is wrong. Alphabet index targets are too small.

### User impact

The count can lie. The list can disagree across tabs. A user can unmatch someone and still see the old count. “1 pals” looks unfinished.

### Current evidence

- `profile_page.dart` `_loadFriendCount()` runs in `initState`; pull-to-refresh reloads profile only.
- `Matches` loads `getConversations` separately.
- `ChatsPage` maps `ChatStateService.conversations`.
- `matches.dart:974` uses `'${filtered.length} pals'`.

### Target experience

One accepted-connection source; every surface agrees.

### Design specification

- Define a single `PalsService` or use `ChatStateService` as the source of accepted connections.
- Profile count subscribes to the same source and refreshes on return from Pals.
- Pluralize: `1 pal`, `2 pals`.
- Alphabet index: preserve 26 letters but give each at least a 24–28px vertical lane and a larger transparent hit area; add `Semantics(label: 'Jump to A')`.
- Empty Pals: “No pals yet” + “Find people” or “Browse skills.”
- Search/filter empty: “No pals match your filters” + Clear filters.

### Acceptance criteria

- [ ] Profile count updates after unmatch/block.
- [ ] Count and list agree across Chats, Pals, Profile.
- [ ] “1 pal” is correct.
- [ ] Alphabet index is usable at 360 and with screen reader.
- [ ] Empty and filtered-empty states have actions.

### Tests

- Widget: pluralization.
- Integration: unmatch updates Profile count after return.
- Manual: 360, 390, 200%.

---

## Case 09 — Requests after accept

**Status:** PARTIAL  
**Priority:** P2  
**PDF reference:** page 15

### Problem

The request loop is complete, but the social payoff is not. Accepting removes the request without a clear “now Pals” moment. Decline has no undo/confirmation. Sent has no filters or accepted history. Copy says “Like back” but the action is “Accept.”

### User impact

The user completes the core social loop and gets no confirmation of what changed. Declining by accident is irreversible. Sent remains hard to scan.

### Current evidence

- `request_page.dart:527`: “Like back to start exchanging skills.”
- `_respond` removes the request immediately.
- Filters are only on Incoming.
- Sent shows pending/declined; accepted disappears.

### Target experience

Acceptance feels like a match. Sent is a usable status list. Decline is deliberate.

### Design specification

#### Accept flow

After server success:

```
┌────────────────────────────────────┐
│ [avatar]                           │
│ You’re now Pals with RJ            │
│ Barong Embroidery                  │
│ [Say hello]     [Keep browsing]    │
└────────────────────────────────────┘
```

- Use a modal bottom sheet or dialog, not a passing snackbar.
- “Say hello” opens the chat.
- “Keep browsing” returns to Requests/For You.
- The accepted connection appears in Pals immediately.
- Remove the incoming request only after success.

#### Decline flow

- Confirm with “Decline request?” if destructive.
- Optional reason? Do not require.
- Offer Undo in the snackbar for a short window if backend supports re-open.
- If not, copy should be clear: “Request declined.”

#### Sent filters

Add:

- Status: All / Waiting / Declined / Accepted.
- Date: All / This week / This month.
- Sort: Newest / Oldest.

Include accepted history if the backend can return it; otherwise label Sent as “Pending and declined” and link accepted to Pals.

#### Copy

- Replace “Like back” with “Accept to become Pals.”
- “They want to connect with you.”
- “Withdraw request” as the action.

### Acceptance criteria

- [ ] Accept shows a match confirmation with Say hello.
- [ ] Request is removed only after success.
- [ ] Decline is confirmed or undoable.
- [ ] Sent has status/date filter.
- [ ] Accepted history is visible or explicitly excluded.
- [ ] Copy matches the action.

### Tests

- Widget: accept sheet.
- Widget: decline confirmation.
- Integration: accepted connection appears in Pals.
- Manual: empty/error states.

---

## Case 10 — Onboarding durability

**Status:** PARTIAL  
**Priority:** P2  
**PDF reference:** page 17

### Problem

Onboarding has a strong visual sequence but no draft persistence, step labels, review screen, or clear skip consequence. Role/chip semantics are missing. Inactive dark dots are invisible.

### User impact

A user who exits mid-flow loses selections. “Do this later” can bypass the data that powers matching. The user cannot review before saving.

### Current evidence

- `onboarding_flow.dart` keeps state in memory.
- `onboarding_intro.dart` dark dots use charcoal.
- `onboarding_scaffold.dart` progress is a bar with no step text.
- `role_card_group.dart`/`chip_selector.dart` use GestureDetector without selected semantics.
- Skip sets `skipped_onboarding` and enters the app.

### Target experience

A user can leave and return without losing progress, understands where they are, and reviews before the profile is saved.

### Design specification

- Persist draft to `PreferencesService` or a local draft object after each step.
- Clear draft after successful `saveOnboardingPreferences`.
- Add step label: “Step 2 of 4 · Role.”
- Add review screen:
  - Role
  - Learning interests
  - Teaching interests
  - Availability
  - Languages
  - Learning style
  - Edit buttons per section
  - “Save and continue”
- Skip dialog:
  ```
  Finish later?
  Your matches will be less relevant until you add
  your role, skills, and availability.
  [Keep editing] [Finish later]
  ```
- On re-entry, show “Continue setup” on Profile if skipped.

### Accessibility

- Role cards: Semantics button + selected.
- Chips: Semantics button + selected + disabled when max reached.
- Back arrow 44×44.
- Progress step announced.
- Dark dots visible.

### Acceptance criteria

- [ ] Draft survives app restart.
- [ ] Step labels exist.
- [ ] Review screen exists.
- [ ] Skip copy explains consequences.
- [ ] Role/chips announce selection.
- [ ] Dark dots visible.
- [ ] Existing save path unchanged.

### Tests

- Widget: draft save/restore.
- Widget: selected semantics.
- Manual: 360/390 dark.

---

# Part B — Clarity and system cases

---

## Case 11 — Copy and routing clarity

**Status:** NEW GAP  
**Priority:** P2  
**PDF reference:** pages 7 and 15

### Problem

Several visible controls do not match their destination or meaning.

### Required edits

| Current | Problem | New copy / behavior | File |
|---|---|---|---|
| “All” filter | Resolves to opposite role, not all | “Recommended” or truly all roles | `home_page.dart` |
| “Update your settings” | Opens Edit Profile | “Update your profile” or route to Settings | `home_page.dart` |
| “Add” | Sends a request | “Send request” or “Connect” | `person_card.dart`, `home_page.dart`, `explore_expand.dart` |
| “Like back” | Conflict with Accept | “Accept to become Pals” | `request_page.dart` |
| “No learning styles set” | Negative placeholder | “Learning style not specified” or hide | `person_card.dart` |
| “1 pals” | Grammar | Singular/plural helper | `matches.dart` |
| “Unsaved Changes … OK” | Ambiguous discard | “Discard changes” / “Keep editing” | `profile_edit.dart` |
| “Continue to Login” after verification | Semantically odd | “Back to Log In” or “Continue” | `scratch.dart` |
| “Delete account … contact support” | No support route | Link to Support | `delete_account_page.dart` |

### Design rules

- Every button label is a verb or a destination.
- No “OK” for destructive choices.
- No placeholder negative text if the row can be hidden.
- The empty-state link text must match its destination.
- Use one helper for counts:
  ```dart
  String palsCount(int n) => '$n ${n == 1 ? 'pal' : 'pals'}';
  ```

### Acceptance criteria

- [ ] No “All” label unless it returns all roles.
- [ ] Empty-state link goes where it says.
- [ ] Add/Connect/Send request is consistent across decks.
- [ ] “Like back” removed.
- [ ] Count grammar fixed.
- [ ] Discard dialog explicit.
- [ ] Delete support copy points to a real route.

### Tests

- Unit: pluralization helper.
- Widget: empty state link target.
- Manual: copy pass at 360/390.

---

## Case 12 — System consistency

**Status:** PARTIAL  
**Priority:** P2  
**PDF reference:** pages 6, 14, 18

### Problem

The system is mostly coherent, but the remaining routes break parity:

- Matches, Blocked Users, Notifications, ChatRoom, AuthGate use centered spinners while the four main tabs use skeletons.
- Blocked Users title is 16 pt; Settings/Change Password/Delete are 20 pt; Matches has no page title.
- Matches uses a bespoke filter sheet while Home/Chats/Requests use `FilterBottomSheet`.
- Some dialogs use older default styles; some error states say “check your connection” for all failures.

### User impact

The app feels assembled from two systems: a polished main shell and older subroutes.

### Design specification

- Add skeletons:
  - `BlockedListSkeleton`.
  - `ActivitySkeleton`.
  - `ChatRoomMessageSkeleton`.
  - `MatchesSkeleton`.
- Standardize page titles: main tab 24, subpage 20.
- Add a `PageHeader` or shared `AppBar` pattern with consistent back target.
- Replace Matches’ custom filter sheet with `FilterBottomSheet.show`.
- Define error copy helper:
  ```dart
  String friendlyError(Object e, {String fallback = 'Something went wrong.'})
  ```
- Use one empty-state component for list pages, with optional action.
- Do not change shipped motion or skeleton behavior on the four tabs.

### Acceptance criteria

- [ ] All data-heavy routes have skeletons.
- [ ] Subpage titles use one scale.
- [ ] Matches uses the shared filter component.
- [ ] Error messages distinguish connection vs validation/server.
- [ ] Back buttons have consistent 44px targets and glyphs.
- [ ] No layout jumps when loading completes.

### Tests

- Widget: skeleton appears before data.
- Manual: 360/390/1440 loading states.

---

## Case 13 — Feedback survey navigation

**Status:** PARTIAL  
**Priority:** P2  
**PDF reference:** page 16

### Problem

The 11-statement survey plus comment step only moves forward. Users cannot revise an answer or skip a statement. There is no draft if the dialog closes.

### User impact

A long survey feels irreversible. Users may abandon it because they cannot correct an earlier answer.

### Design specification

- Add **Back** alongside Next/Submit.
- Add **Skip** for optional statements? If all statements are required, do not add skip; instead add “Prefer not to answer.”
- Store answers in local state map; back returns to the previous statement with the selected value.
- Progress:
  ```
  Step 4 of 12
  [progress]
  ```
- Final step: summary? At minimum, allow Back to edit statements.
- On Cancel, confirm:
  ```
  Discard feedback?
  Your answers will be lost.
  [Keep writing] [Discard]
  ```
- Do not add a second submission path; reuse `submitAppFeedback`.

### Acceptance criteria

- [ ] Back works and preserves previous answer.
- [ ] Current step and total shown.
- [ ] Cancel confirms loss.
- [ ] Submit still writes one payload.
- [ ] iOS and Android dialogs both support Back.
- [ ] Keyboard does not hide the actions.

### Tests

- Widget: back preserves selection.
- Widget: submit payload unchanged.
- Manual: iOS-style dialog, 360.

---

## Case 14 — Auth and accessibility polish

**Status:** PARTIAL  
**Priority:** P2  
**PDF reference:** pages 17–18

### Problem

Auth flows work, but small targets and semantics remain:

- Login has no inline validation before service call.
- “Forgot Password?” is a text-only gesture.
- Registration legal links are 12pt text spans.
- Onboarding back icon is 18px.
- Role cards/chips do not announce selected state.
- 200% text is untested on core screens.

### Target experience

Auth and onboarding are as accessible as the main shell.

### Design specification

#### Login

- Validate email format and non-empty password before request.
- Show inline errors under fields.
- Convert “Forgot Password?” to a 44px TextButton.
- Add autofill hints: email, password.
- Show keyboard submit action.

#### Register

- Legal links become 44px tappable buttons or a single line of buttons below the form.
- Keep the text style but not the tiny tap area.
- Announce error summary to screen readers.

#### Onboarding

- Back icon inside a 44×44 `IconButton`.
- Role cards/chips use `Semantics(button, selected)`.
- Step labels.
- Test 200% text.

#### 200% text

- For You card: preserve media, allow text to expand within the card; bio clamp already scrolls.
- Settings: rows wrap, switches stay accessible.
- Chat header: name truncates, actions remain visible.
- Edit Profile: labels wrap, Save remains reachable.

### Acceptance criteria

- [ ] Empty login shows inline validation.
- [ ] Forgot link is 44px.
- [ ] Legal links are 44px.
- [ ] Onboarding back target 44px.
- [ ] Role/chips announce selected.
- [ ] 200% text passes on card, settings, chat header, edit.
- [ ] No content hidden behind the floating nav.

### Tests

- Widget: semantics selected.
- Manual: 200% text and keyboard focus.
- Accessibility: TalkBack/VoiceOver spot check.

---

# Part C — Cross-case implementation sequence

## Phase 1 — Structural clarity (P1)

1. Case 01 — Account & Settings hierarchy
2. Case 02 — Browse depth
3. Case 03 — Category card context
4. Case 04 — Edit Profile structure and role safety
5. Case 05 — Dark-mode edges

**Outcome:** The account, browse, and edit models are understandable without guessing.

## Phase 2 — Social completion (P2)

6. Case 06 — Activity destination
7. Case 07 — Chat state model
8. Case 08 — Pals integrity
9. Case 09 — Requests after accept
10. Case 10 — Onboarding durability

**Outcome:** The social loop has a clear after-request life and lossless onboarding.

## Phase 3 — Clarity and system (P2)

11. Case 11 — Copy and routing
12. Case 12 — System consistency
13. Case 13 — Feedback survey navigation
14. Case 14 — Auth and accessibility polish

**Outcome:** The product speaks with one voice and passes accessibility and loading parity.

## Dependencies

- Case 01 must land before removing Delete from Settings.
- Case 06 depends on notification payload shape and routing.
- Case 07 must not change `ChatStateService` unread semantics without updating C06.
- Case 08 must use the same accepted-connection source as Case 07.
- Case 12 skeleton work must not regress C14.
- Case 14 200% text work should follow Case 04, or it will be repeated.

---

# Part D — Verification matrix

| Case | Unit | Widget | Integration | Manual 360/390/1440 | Dark | 200% |
|---|---|---|---|---|---|---|
| 01 Account IA | — | Yes | — | Yes | Yes | Yes |
| 02 Browse | — | Yes | Yes | Yes | Yes | Yes |
| 03 Category card | — | Yes | — | Yes | Yes | Yes |
| 04 Edit Profile | — | Yes | — | Yes | Yes | Yes |
| 05 Dark edges | — | Yes | — | Yes | Yes | — |
| 06 Activity | Yes | Yes | Yes | Yes | Yes | Yes |
| 07 Chat state | Yes | Yes | Yes | Yes | Yes | Yes |
| 08 Pals | Yes | Yes | Yes | Yes | Yes | Yes |
| 09 Requests | — | Yes | Yes | Yes | Yes | Yes |
| 10 Onboarding | — | Yes | — | Yes | Yes | Yes |
| 11 Copy/routing | Yes | Yes | — | Yes | Yes | — |
| 12 System consistency | — | Yes | — | Yes | Yes | Yes |
| 13 Survey | — | Yes | — | Yes | Yes | — |
| 14 Auth/a11y | — | Yes | — | Yes | Yes | Yes |

### Definition of done for every case

- [ ] Default, loading, empty, error, dark states reviewed.
- [ ] 360×640 and 390×844 checked.
- [ ] 1440×900 shell checked for layout regressions.
- [ ] 200% text checked on text-heavy screens.
- [ ] Every tappable element ≥44×44.
- [ ] Semantics labels and selected states verified.
- [ ] No regression to C01–C15.
- [ ] Copy reviewed against Section 2.6.
- [ ] No dead-end action.
- [ ] No false success state.

---

# Part E — Open product decisions

These decisions must be made before implementation to avoid churn:

1. **Should a right swipe send immediately, or open a request preview?**
   - Current: sends. If changed, C02 must be carefully preserved.
2. **Is showcase required for every mentor, or only “both” users?**
   - Affects Edit Profile and matching completeness.
3. **Does “All” mean all roles or all recommendations?**
   - Current behavior is opposite-role; choose label or data.
4. **Should Activity mark items read individually or all at once?**
   - Affects badge semantics and server calls.
5. **Is email change in scope?**
   - If not, Account should show read-only email and say so.
6. **Are active sessions available from Supabase?**
   - If not, do not fake a device count.
7. **Should Browse count people by taxonomy usage or actual accepted profiles?**
   - Use a real count or hide the number.

---

# Part F — Evidence map

| Area | Files |
|---|---|
| Settings / account | `lib/screen/settings.dart`, `lib/screen/account/*` |
| Browse | `lib/screen/explore_page.dart`, `lib/screen/explore_expand.dart`, `lib/services/match_api.dart` |
| For You | `lib/screen/home_page.dart`, `lib/screen/card/person_card.dart` |
| Profile | `lib/screen/profile_page.dart`, `lib/screen/profile_edit.dart` |
| Activity | `lib/screen/notifications_page.dart`, `lib/services/activity_service.dart` |
| Chats | `lib/screen/chats_page.dart`, `lib/screen/chats_room.dart`, `lib/services/chat_state_service.dart` |
| Requests / Pals | `lib/screen/request_page.dart`, `lib/screen/matches.dart` |
| Onboarding | `lib/onboarding/*`, `lib/onboarding_intro.dart` |
| Auth | `lib/authentication/*` |
| Theme / motion | `lib/theme/app_colors.dart`, `lib/theme/theme.dart`, `lib/theme/app_motion.dart` |

### Reference evidence

- `PalTuro-Design-Feature-Audit-v2-2026-10-25.pdf`
- `PalTuro-Initial-UI-Feature-Implementation-Report.pdf`
- `UI-FEATURE-AUDIT-TODO.md`
- `UI-AUDIT-TODO.md` previous UI refinement tracker
- Current render captures at 390 light/dark and existing 360/1440 evidence

---

## Closing principle

The app already looks like PalTuro. The remaining work is to make the **account**, **browse**, and **edit** surfaces feel as deliberate as the match deck — and to make every post-request state lead somewhere clear.

Do not add more visual decoration before these cases are closed. The strongest next version is the one where a user can explain where they are, what they changed, and what happens next without leaving the screen.
