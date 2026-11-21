# Card-level matching rework

Status: proposal. Nothing below is implemented yet except where marked.

Scope: `get-matches`, `match_candidates`, `profile_embeddings`, the For You deck,
and the request/notification payloads that depend on "which skill matched".

---

## 1. Verdict

The reported case is not a ranking bug. It is a **data-model mismatch**:

> The product matches *a person's skill intent* (learn X, teach Y). The system
> matches *whole profiles* through one aggregated vector per role.

Because a profile is collapsed into a single "mentor" vector and a single
"learner" vector, the matcher cannot represent "this person wants Traditional
Music" separately from "this person also wants three other things". It also has
no hard rule that the two sides must share a skill. The deck therefore pads
itself with plausible-looking profiles and the UI shows whichever skill happens
to be first alphabetically.

---

## 2. How it works today (evidence)

### Data

| Object | Shape | Notes |
|---|---|---|
| `user_skills` | `(user_id, skill_id, kind, note, note_approved, tags)` | `kind` ∈ `teach` / `learn` / `secondary` |
| `enforce_skill_caps` | trigger | max **3** per `kind` (`secondary` exempt) |
| `skill_showcases` | `(user_id, skill_id?, media_url, …)` | `skill_id` is **nullable**; not used by matching |
| `profiles.learning_skills` / `teaching_skills` | text[] | legacy mirrors, synced by trigger |
| `profile_embeddings` | `(user_id, role, field_group, input_type, embedding 1024d)` | 4 passages × 2 input types = **8 vectors/user** |
| `match_cache` | PK `(user_id, as_role, candidate_id)` | user-level, no card columns |

### Pipeline (`supabase/functions/get-matches/index.ts`)

1. `as_role` chooses the target role (the role of the candidates).
2. Owner embeddings are self-healed.
3. `match_candidates` (SQL) builds candidates with **one cosine** between the
   viewer's aggregated `skills` vector and each candidate's aggregated
   `skills` vector, plus a `context` vector; weights default `skills 0.7`,
   `context 0.3`.
4. It **unions a fallback**: any 200 users that have at least one skill of the
   target kind (`limit 200`), regardless of overlap.
5. `profile_match_view` rebuilds the aggregated offer/context text per user.
6. Direction A reranks candidates; direction B asks "does the candidate also
   want me?", bounded to `rerank_b_limit` (10).
7. `combineReciprocal` (geometric mean by default) → `calibrated_score`, which
   is **the only final score**. No skill component, no threshold.
8. Sort, drop existing connections/blocks, cap at `max_deck_size` (20), cache.

### Client (`lib/services/match_api.dart`, `home_page.dart`)

- Fetches **both** decks (`as_role=learner` and `as_role=mentor`), 10 each.
- Merges and **dedupes by user id**, so a person can only appear once.
- Enriches each match with `get_public_profile`, then
  `personFromPublicProfileMap` picks `preferred.first` — the **first skill by
  name**, not the skill that matched.
- A request sends `skill_name`/`skill_path` (the connection already supports
  skill context), but the card that produced it may show a different skill.

### What the design doc already promised

`docs/matching-variables.md` specifies the structured layer (`best_skill_pair`,
`skill_exact`, `require_discovery_media`, `min_skill_score`,
`min_final_score`, `matched_skill_id`). None of those tokens appear in the code
or SQL. The document describes the *intended* precision layer; the runtime is
embedding-only.

---

## 3. Why the reported pair was shown

Viewer **A** teaches Web Development. Candidate **B** wants to learn Traditional
Music.

1. A is browsing the "learners" deck (A as mentor, candidates as learners).
2. `match_candidates` puts **every** learner in the fallback pool (up to 200),
   with no requirement that B wants anything A teaches.
3. A's mentor vector is an average of all A's teaching skills; B's learner
   vector is an average of all B's learning skills. Unrelated skills still land
   at a middling cosine.
4. Context contributes 30%, and the reranker scores "is this a plausible
   learner for this mentor?" on whole-profile text. A generic answer passes.
5. There is **no `min_skill_score` or `min_final_score`** check, so a weak pair
   still enters the top 20.
6. `require_discovery_media` is documented but not implemented. A teaching
   skill **without a showcase** is still matchable — exactly the "profile 1 had
   the skill but no showcase" observation.
7. The card then displays the first teaching/learning skill alphabetically, so
   the visible skill may not even be the one that scored.

Nothing in that chain is a bug in isolation. It is the consequence of matching
profiles instead of skill intents.

---

## 4. Target model: match skill cards

### Card entity

```
skill_card {
  id            uuid
  user_id       uuid
  kind          learn | teach
  skill_id      uuid            -- leaf node
  note          text?           -- approved note, or null
  visibility    discoverable | paused | hidden
  showcase_ids  uuid[]          -- teach cards need an approved showcase
  updated_at
}
```

- One card per `user_skills` row initially (1:1). A `skill_cards` **view over
  `user_skills`** can ship first; a real table is only needed when per-card
  visibility/showcase binding must be enforced.
- Caps: **3 learn + 2 teach = 5 cards max** (product decision; today it is 3+3).
- Teach cards are discoverable only when they have an approved showcase.
- Learn cards need no showcase.

### Matching unit

A match is a pair of cards on **compatible skill nodes**:

```
(their learn card) ↔ (my teach card)     -- when I am browsing learners
(their teach card) ↔ (my learn card)     -- when I am browsing mentors
```

- Skill compatibility uses the taxonomy tree (`ltree`): exact 1.0, child 0.8,
  parent 0.65, sibling 0.45 (configurable), unrelated 0.0.
- **Hard gate**: `skill_score > 0`. Unrelated cards never enter For You.
- The deck item carries `card_id`, `skill_id/path/kind`, `note`, `showcase`,
  `compatibility`, and `match_card_id`.
- A user may appear up to 5 times across the whole system, at most once per
  card. In a single deck, `max_per_user` (default 1–2) decides.

### Scoring

Keep the sign of the existing pipeline but score **card pairs**:

```
skill   = compatible_node_score(my_card.skill, their_card.skill)   // 0..1
context = weighted(language, availability, styles)                // 0..1
bi      = w_skills * skill + w_context * context
rerankA = rerank(my_card.text, their_card.text)                   // pair fit
rerankB = rerank(their_card.text, my_card.text)                   // reciprocity
final   = reciprocal(rerankA, rerankB) * (base + skill_boost * skill
                                          + context_boost * context)
final   = clamp(final, min_multiplier, max_multiplier)
```

The parameters already exist in `docs/matching-variables.md`; this rework is
mostly implementing that contract at card granularity. Add:

- `min_skill_score` (hard gate, default 0.01)
- `min_final_score` (display gate)
- `require_discovery_media` (teach cards only)
- `max_per_user`, `max_per_skill`, `repeat_penalty`

---

## 5. Schema and pipeline changes

### New / changed data

| Change | Why |
|---|---|
| `skill_cards` table or view | Card identity, visibility, showcase binding |
| `card_embeddings (card_id, input_type, embedding)` | Per-card skill vectors; HNSW index |
| `skill_showcases.skill_id` NOT NULL for teach | Makes the showcase gate enforceable |
| `match_cache_v2 (viewer, as_kind, candidate_card, …)` | Cache the card pair, not the user |
| `connections.card_id` (optional) | Know which card the request came from |
| `notifications` payload: `card_id`, `kind`, `skill_path` | Possible-match notifications become card-specific |

### New SQL surface

- `build_card_passages(p_card)` → `skills` passage + card text.
- `match_cards(p_user, p_target_kind, p_limit, p_params)` → card pairs with
  `skill_score`, `bi_score`, `candidate_card_id`, `source_card_id`.
- Keep `build_profile_passages` only for the **context** group.
- `cache_is_fresh` must also watch `skill_cards.updated_at`,
  `skill_showcases.updated_at`, and visibility changes.

### Edge function

- Response item: `user_id`, `card_id`, `source_card_id`, `skill_id`,
  `skill_name`, `skill_path`, `kind`, `note`, `compatibility`, `pipeline`.
- Rerank direction A over card texts; direction B bounded per pair.
- Diversity pass: `max_per_user`, `max_per_skill`, `max_per_category`.

### Client

- `Person` → `MatchCard` (or add `cardId`/`sourceCardId`/`skillKind`).
- Deck/seen/replay keys become card ids; migrate the local seen set (safe: card
  ids are new, so users see the guide/deck once more).
- A request passes the card's skill (already supported server-side).
- Profile page still shows the whole person; the deck card shows one intent with
  a "wants to learn X" vs "teaches Y" badge.

---

## 6. Cost

### Engineering (one developer, familiar with the repo)

| Phase | Work | Estimate |
|---|---|---|
| 0 | Stopgap gates (see §8) — no schema change | **1–2 days** |
| 1 | `skill_cards` view + `card_embeddings` + backfill | **4–6 days** |
| 2 | `match_cards` + edge function + cache v2 + tests | **8–10 days** |
| 3 | Client cards, seen keys, request payload, UI badges | **5–7 days** |
| 4 | Dual-run, cutover, remove user-level path | **3–5 days** |

Total ≈ **4–6 weeks** solo, ~3 weeks with a second pair of hands. Phase 0 is a
day or two and fixes the reported class of bug immediately.

### Runtime / infra

- **Embeddings**: today 8 vectors/user (4 passages × passage+query). Cards:
  5 cards × 2 + 2 context groups × 2 = **14 vectors/user** (+75% per profile
  save, but profile saves are rare). Backfill is one batch per user.
- **Rerank**: direction A stays one batch. Direction B becomes per **pair**
  instead of per candidate; bound it to `rerank_b_limit` pairs (default 10) and
  reuse the existing deadline/budget. Expect **+20–60%** rerank calls on a cold
  deck, unchanged on cached decks.
- **Storage**: 1024 × 4 B ≈ 4 KB/vector. +6 vectors/user ≈ +24 KB/user
  (~240 MB per 10k users, before index overhead).
- **Latency**: prefilter by `skill_id`/`ltree` before vector search should keep
  the candidate pool small; expected **neutral to +30%** on cold loads.
- **Model spend**: embeddings and rerank are the only paid calls; the delta is
  proportional to the vector/rerank increase above, not a new cost centre.

### Operational

- Dual-write/dual-run while `match_cache_v2` fills.
- One backfill migration with a progress report; no destructive column drops
  until cutover.
- Cache flush per config revision (already supported).

---

## 7. Edge cases and logic flaws to settle

1. **Same person, multiple cards.** Today `_mergeDecks` dedupes by user id. Cards
   break that assumption. Decide `max_per_user` per deck; otherwise a user with
   5 cards floods the feed.
2. **Learn and teach the same skill.** Exclude self-pairs; optionally allow a
   "peer" mode later, but not in For You.
3. **Taxonomy depth.** "Traditional Music" and "Music Theory" may be siblings
   under Music. Sibling 0.45 should *not* pass the hard gate by default; the
   current doc allows it, which reproduces the complaint at a smaller scale.
4. **General vs specific.** "General Programming" ↔ "Python" is 0.55/0.50. A
   hard gate must include these or the deck starves; make the gate
   `>= min_skill_score` (e.g. 0.4), not `== 1`.
5. **Showcase removed after a match.** Teach card becomes hidden; cache must
   invalidate; an existing connection stays.
6. **Note pending or rejected.** Still match on the skill, hide the note (today
   `note_approved` already gates the text).
7. **Visibility toggles.** Paused/hidden cards must leave decks and caches
   immediately; no stale card in `match_cache`.
8. **Cap reduction 3 → 2 teach.** Do not delete data. Keep the third card
   `hidden` with a migration note; product decides later.
9. **Connections are user-level.** One accepted connection blocks every card
   between two people. Card-level connections are a bigger change; decide
   whether it is in scope.
10. **Blocks/reports stay user-level.** All cards excluded, both directions.
11. **Seen/replay keys.** Person ids become card ids; the existing local seen
    set becomes inert (acceptable) but must not hide people forever.
12. **Deck exhaustion.** 5 cards × fewer unique people means the deck empties
    faster; `getRandomDeck`/Browse is the escape hatch, not a fallback pool in
    For You.
13. **First-card guide.** Now per card; decide whether "first card" means first
    *unique person* or first card (recommend unique person).
14. **Possible-match notifications.** One per person per 24h, not one per card;
    payload needs card/skill context or the existing UI will mislabel.
15. **Requests.** The card's skill must be stored; today the client can send a
    skill different from the card that matched.
16. **Unmatch/decline/reopen.** `connections` rows are user-level; reopening a
    declined request must not resurrect a hidden card.
17. **Cache cardinality.** `(viewer, card, candidate_card)` explodes. Cache per
    `(viewer, as_kind, candidate_card)` and cap `max_deck_size`; prune old rows.
18. **Cold start.** A new user has cards but no embeddings yet; the structured
    `skill_score` path must work without vectors (docs already require this).
19. **Stale embeddings.** Note edits, taxonomy rename/merge, node visibility
    changes. Hash per card; `cache_is_fresh` watches `skill_cards`.
20. **Fairness.** Popular cards dominate For You; `max_per_skill`,
    `max_per_category`, and a per-candidate exposure cap are needed.
21. **Privacy/RLS.** A cards table exposes intent; RLS must mirror
    `profile_visible` and never leak hidden/paused cards to other users.
22. **Moderation.** Deleting a skill node or a showcase must cascade to cards
    and caches; admin tooling needs a card view.
23. **Labels.** Node name vs slug; the card should keep the leaf name and the
    chain for the "why this match" sheet.
24. **Abuse.** Five cards per user multiply exposure and notification volume;
    keep the existing rate limits per surface, not per card.

---

## 8. Phase 0 stopgap (recommended now)

No schema change. Fixes the reported class of bug in a day or two:

1. **Hard overlap gate.** In `match_candidates` (or as a post-filter in
   `get-matches`), require at least one compatible pair between the viewer's
   opposite cards and the candidate's cards. Drop the arbitrary 200-user
   fallback from For You (keep it for Browse).
2. **Thresholds.** Enforce `min_skill_score` and `min_final_score`; never pad a
   deck with unrelated profiles.
3. **Matched skill in the response.** Return `matched_skill_id/path/kind` and
   have the client render that skill instead of `preferred.first`.
4. **Showcase gate.** Exclude teach cards without an approved showcase
   (`require_discovery_media`).
5. **Tests** (deterministic fixtures):
   - viewer teaches Web Dev ↔ candidate wants Traditional Music → **excluded**
   - viewer teaches Web Dev ↔ candidate wants Web Dev → **included**
   - teach card without showcase → **excluded**
   - exact match ranks above sibling/context-only
   - empty deck is allowed; it must not be padded with unrelated people

Phase 0 does not deliver per-card visibility or the 5-card UX. It stops the
"unrelated person in my feed" failure while the full rework is scheduled.

---

## 9. Decisions needed

1. **2 teach or 3?** The proposal says 3 learn + 2 teach = 5. Today it is 3+3.
2. **Is a showcase mandatory for every teach card**, or only for the card to be
   discoverable (my recommendation: discoverable only; the card stays usable in
   the profile)?
3. **Can the same person appear more than once in one deck?** (`max_per_user`
   default 1 or 2.)
4. **Skill hierarchy gate**: siblings pass or not? Exact/child/parent only?
5. **Card-level connections** now, or keep connections user-level and revisit?
6. **For You layout**: keep one merged feed, or split Learn / Teach tabs? Card
   matching makes the split natural.
7. **Migration policy** for existing third teaching skills.

---

## 10. Acceptance criteria

- No For You card without a compatible skill pair (hard gate).
- The card's visible skill is the card that matched.
- A user with 5 cards appears at most `max_per_user` times per deck.
- Hidden/paused cards and showcase-less teach cards never appear.
- Cache invalidates on card, note, showcase, and visibility edits.
- Exact pairs outrank siblings, which outrank context-only candidates.
- Deck starvation is surfaced as "no more matches", never padded.
- Deterministic fixtures cover the reported case, reciprocity, caps, and
  visibility.
