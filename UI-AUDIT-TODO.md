# UI refinement tracker

Branch: `ui-refine`
Base: `1b6cac3`
Source audit: `PalTuro-UI-UX-Audit-Report.pdf`

Each case is complete only after functionality, quality, and regression subagent
audits all return `PASS`. The tracker is updated before the next case starts.

## Ordered cases

1. [x] P0-04 Contrast and text tokens
2. [x] P0-03 Dark elevated surfaces
3. [x] P0-01 Login small-screen layout
4. [x] P0-02 Startup delay
5. [x] P0-05 Semantics and tap targets
6. [x] P1-02 Navigation icons, SafeArea, motion
7. [x] P1-01 Branding, splash, metadata
8. [x] P1-03 Settings header, footer, switches
9. [x] P1-04 Profile role badge
10. [x] P1-05 Request chevron
11. [x] P1-06 Filter cleanup
12. [x] P1-07 Disabled actions
13. [x] P1-08 Avatar fallback
14. [x] P2-01 Shared motion scale
15. [x] P2-02 Consistent card exit
16. [x] P2-03 Tab fade and dead Hero
17. [x] P2-04 Loading skeleton
18. [x] P2-05 Empty-state links
19. [ ] P2-06 Chat timestamps
20. [ ] P2-07 Profile edit header and save
21. [ ] P2-08 Person-card fallback
22. [ ] P2-09 Unread badge
23. [ ] P2-10 Desktop max width

## Audit log

| Case | Functionality | Quality | Regression | Notes |
|---|---|---|---|---|
| P0-04 | PASS | PASS | PASS | Added accessible accent/muted tokens, removed lime-on-white foregrounds and gray nav labels, fixed dark attachment chip, 21 tests green. |
| P0-03 | PASS | PASS | PASS | Added elevated/muted/border surfaces, applied to cards/nav/sheets/dialogs, kept page surface separate, fixed auth scaffold and nested-surface inversions, 23 tests green. |
| P0-01 | PASS | PASS | PASS | Responsive login: 285/190/150 logo tiers, compact gap/footer; 360/320 fit, 390 safe-area keeps original layout; 23 tests green. |
| P0-02 | PASS | PASS | PASS | Native splash removed on first frame; root gate 200ms; landing 600ms; total ~0.8s, deep-link guards intact. |
| P0-05 | PASS | PASS | PASS | Named 44px icon actions, pager zones, skills/photo controls, dialogs; 20px dots with >10 counter; nav semantics activate. |
| P1-02 | PASS | PASS | PASS | People/Requests glyphs corrected, SafeArea bottom gap, 180ms scale press, 12px labels, semantics intact. |
| P1-01 | PASS | PASS | PASS | Removed DRAFTR, regenerated splash with white dark branding, capped web splash, updated metadata/manifest, documented regeneration. |
| P1-03 | PASS | PASS | PASS | Settings back header/title, scrollable Account section, no fixed footer, readable off switch and dark dividers. |
| P1-04 | PASS | PASS | PASS | Profile role is an intrinsic 44px non-interactive badge with a Role label; edit/onboarding remain three 120px cards. |
| P1-05 | PASS | PASS | PASS | Request card uses a right chevron matching detail navigation; taps/Accept/Decline/layout unchanged. |
| P1-06 | PASS | PASS | PASS | Removed dead Skills/Coming soon sections; Requests section renamed Sort by; all filters still apply/reset. |
| P1-07 | PASS | PASS | PASS | Feedback Next and report Submit are truly disabled and gray until valid; report reason uses the same enabled/disabled tokens. |
| P1-08 | PASS | PASS | PASS | Shared UserAvatar initials-on-neutral fallback across chats, Pals, requests, profile, chat room, block list; images/error fallback preserved. |
| P2-01 | PASS | PASS | PASS | Added AppMotion press/micro/base/screen/exit/feedback; migrated all UI durations; nav respects reduce-motion. |
| P2-02 | PASS | PASS | PASS | Person-scoped 280ms exits for Home/Explore; button and swipe paths advance once; stale late actions no longer dismiss another card. |
| P2-03 | PASS | PASS | PASS | State-preserving 200ms tab crossfade with hidden pages muted/excluded; Hero has a live Login↔Register counterpart, so it was retained. |
| P2-04 | PASS | PASS | PASS | Card-shaped cold-load skeleton with semantics/shimmer token; cached/refresh/error paths untouched; 25 tests. |
| P2-05 | PASS | PASS | PASS | Empty-state settings/Swiping spans now accent + underline with semantics link action; recognizers unchanged. |
