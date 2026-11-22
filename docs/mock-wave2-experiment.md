# Mock wave 2 experiment — 10 new users

Date: 2026-11-22 · Production (`yjcrfgvenilptrnudvcb`) · `matcher_mode = cards`

## Setup

10 tagged accounts, `mock21@palturo.dev` … `mock30@palturo.dev`:

| Skill side | New users |
|---|---|
| Teach Traditional Music | 21 Aurora, 22 Benito, 23 Corazon |
| Teach Filipino Cooking | 24 Dalisay, 25 Esteban |
| Teach Dessert Making | 26 Fiorella |
| Teach Calligraphy | 27 Gregorio |
| Teach Nail Art | 30 Jasmine |
| Learn Cooking / Dessert / Music | 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 |

Tags: `mock=true`, `mock_batch="2026-11-22-wave2"`, `[MOCK]` bio prefix.
23 cards (9 teach, 14 learn), 8 showcases, 80 profile vectors + 46 card vectors.

Seed wall time: **72.4 s** total — 2.58 s auth users, 1.09 s SQL, 68.77 s embeddings
(57 upserts across 10 `generate-embeddings` calls).

Method: 7 observers × 2 roles, caches cleared, cold (`refresh:false`) then warm
(`refresh:true`). Compatibility is deterministic for retained cards.

## Rank shifts

| Deck | Before | After | In | Out |
|---|---|---|---|---|
| realA / learner | Mikaela, Camille, Diego | Mikaela, **Aurora**, Camille | Aurora (#2) | Diego (#3) |
| realA / mentor | Liza, Fernando, Juan | **Benito**, Liza, **Corazon** | Benito (#1), Corazon (#3) | Fernando, Juan |
| realB / learner | Trina, Camille, Rico | **Inigo**, Trina, Camille | Inigo (#1) | Rico (#3) |
| realC / mentor | Maria Clara, Jose Rizal, Gabriela | Maria Clara, **Esteban**, **Dalisay** | Esteban (#2), Dalisay (#3) | Jose Rizal, Gabriela |
| mock01 / learner | 6 cards | 6 cards | Hilda (#1) | one Mikaela card |
| mock01 / mentor | Nadia | **Gregorio**, Nadia | Gregorio (#1) | — (deck grew 1→2) |
| mock11 / mentor | 6 cards | 6 cards | Dalisay (#2), Fiorella (#6) | one Maria Clara card, Apolinario |
| mock14 / mentor | 6 cards | 6 cards | Benito (#1), Esteban (#4), Corazon (#5) | Fernando, Juan, Gabriela |
| mock19 / mentor | 9 cards | 9 cards | Aurora (#3), Dalisay (#4), Esteban (#5), Fiorella (#8), Benito (#9) | Melchora, one Maria Clara card, Juan, Liza, Apolinario |

Totals across the 9 non-empty decks: **18 entrants, 17 exits, 15 retained cards
changed rank**. Top-1 changed in **5 of 9** decks.

Key mechanics:

- Retained cards kept exactly the same compatibility. All movement is relative
  rank from new higher-scoring cards, not score drift.
- `max_per_skill = 3` and `max_per_user = 2` cause the displacement. With six
  cooking mentors eligible, only three can show; two new higher-scoring mentors
  evicted two incumbents.
- `mock01/mentor` is the one deck that grew (1→2) because calligraphy had only
  one eligible mentor before.

## Notifications

| Metric | Before | After |
|---|---|---|
| `possible_match` notifications | 66 | **96 (+30)** |
| `possible_match_jobs` done | 67 | **79 (+12)** |
| pending jobs | 0 | 1 |

All 30 new notifications were **to mock recipients about wave2 candidates**;
**zero real accounts** were notified in this batch. Sample payload:
`{reason:"media", as_role:"mentor", skill_name:"Filipino Cooking",
candidate_id:"…"}`. One job remained pending at measurement time.

The removal script now deletes notifications whose payload references a mock
candidate, so no stale possible-match cards remain after cleanup.

## Compute and time

| Metric | Before | After |
|---|---|---|
| Cold deck avg | 3,383 ms | **3,032 ms** |
| Cold deck median / max | — | 3,650 / 7,295 ms |
| Warm deck avg / max | 389 / 580 ms | **374 / 561 ms** |
| `get_matches` inference calls | 61 | **70 (+9)** |
| Rerank latency total | 227.9 s | 261.0 s (+33.1 s) |
| `match_cards` SQL calls | 43 | **62 (+19)** |
| `match_cards` total / mean | 1,465 ms / 24.3 ms | 2,324 ms / **24.3 ms** |
| Database size | 55 MB | **56 MB** |
| `match_cache_v2` rows | 40 | 41 |

Reading:

- No cold-deck regression from +10 users; the 3.0–3.4 s average is dominated by
  rerank variance. Warm decks stay ~0.37 s.
- Retrieval cost is flat at ~24 ms per `match_cards` call; the extra time is
  provider rerank work (~3.7 s per non-empty cold deck).
- Storage growth is ~1 MB for 10 users (80 profile + 46 card vectors).
- Host CPU/RAM are not exposed by the project API; the numbers above are the
  available latency/DB proxies.

## Caveats

- 14 deck samples; rerank latency is noisy.
- One possible-match job was still pending when measured.
- The +30 notifications were confined to mock recipients, so the experiment did
  not send real-user notifications.

## Cleanup

All mock accounts (wave 1 + wave 2) share the `mock%@palturo.dev` + `mock=true`
tag:

```powershell
powershell -ExecutionPolicy Bypass -File supabase\tests\remove_mock_accounts.ps1 -Confirm
```
