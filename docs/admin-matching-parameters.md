# PalTuro Admin Console — Matching Panel Parameter Reference

- **Project:** PalTuro production (`yjcrfgvenilptrnudvcb`)
- **Snapshot:** 2026-11-22 · config revision **343** · `matcher_mode = cards`
- **Source of truth:** `pipeline_config`, read by `get-matches`,
  `generate-embeddings`, `admin-api`, `classify-skill`, `moderate-notes`, and
  the possible-match SQL worker.

This document covers every key the Matching panel can edit, plus the derived and
reserved keys it shows or rewrites. All values are the live production values at
the snapshot above.

---

## Contents

1. How the panel works
2. How a card deck is scored
3. Card matching
4. Reciprocal scoring
5. Retrieval and embeddings
6. Rerank throughput
7. Rate limits
8. Decision and moderation
9. Other keys (possible-match notifications and worker)
10. Derived keys (hidden in the editor)
11. Operating recipes
12. Change checklist
13. First-response checks
14. Appendix — quick reference

---

## 1. How the panel works

- **Draft** saves a copy in `pipeline_config_versions`; nothing changes for users.
- **Publish** writes the whole config atomically, bumps `__revision`, stores a
  version, records an audit entry, and clears `match_cache` and
  `match_cache_v2`. A reason is required.
- **Rollback** republishes an earlier version snapshot.
- The panel accepts any number or string. The runtime **clamps** most numeric
  keys to its own range (documented per key). Invalid enums fall back to the
  code default.
- Provider presets own the endpoint and model. Publishing rewrites
  `embedding_model`, `embedding_api`, `rerank_model`, `rerank_api`, and
  `inference_provider` from the selected providers. Those keys are hidden in the
  editor.
- `__revision` is managed automatically and cannot be edited.
- Keys marked **Reserved** are editable and published but **no code reads them**.
  Changing them has no effect.

### Matcher modes

| Mode | Retrieval | Rerank | Skill gate | Thresholds | Diversity caps | Cache |
|---|---|---|---|---|---|---|
| `profile` | whole-profile vectors + 200-user fallback | yes | **no** | no | no | v1 |
| `gated` | card-compatible candidates | yes | **yes** | `min_skill_score`, `min_final_score` | no | v1 (bypasses read) |
| `cards` | one row per compatible card pair | yes, per card | **yes** | `min_skill_score`, `min_final_score` | `max_per_user`, `max_per_skill` | v2 |

`profile` is the legacy behavior and the rollback. It can show a profile with no
skill overlap. `gated` adds the overlap gate to the profile reranker. `cards` is
the current production mode.

---

## 2. How a card deck is scored

1. **Card gate** — a learner card pairs with a teach card on the same taxonomy
   tree. `skill_score` is exact **1.00**, ancestor **0.80**, descendant **0.65**,
   sibling **0.45**, unrelated **0.00**. Cards below `min_skill_score` are dropped.
2. **Bi-encoder score** — `bi = w_skills × card similarity + w_context × context
   similarity`, using `embedding_weights.skills` and `.context` (defaults 0.7 /
   0.3).
3. **Rerank** — direction A scores the candidate card against the viewer card.
   Direction B asks whether the candidate wants what the viewer offers, bounded
   by `rerank_b_limit`.
4. **Reciprocal** — A and B are combined with `reciprocal_formula`. With only A,
   A is used; with neither, the bi score is used.
5. **Calibration** — cards mode sets
   `final = max(reciprocal, bi_score)`. This floors the score so compressed
   rerank outputs cannot empty a valid exact-match deck. Gated mode uses the
   reciprocal alone.
6. **Final filter** — `final >= min_final_score`.
7. **Diversity** — cards mode enforces `max_per_user` and `max_per_skill`, then
   caps at `max_deck_size`.
8. **Cache** — v1 (`match_cache`) for profile/gated, v2 (`match_cache_v2`) for
   cards. A cached deck is served until the revision or a profile/card/showcase
   timestamp changes.

---

## 3. Card matching (group: “Card matching”)

### `matcher_mode` — Matcher mode
**enum** · live `cards` · default `profile` · allowed `profile | gated | cards`

Selects the matching architecture. `cards` is the current production mode and
the only mode that uses per-card identity, card embeddings, the diversity caps,
and `match_cache_v2`. `gated` is a rollout step that keeps the profile reranker
but requires a compatible card. `profile` is the legacy whole-profile matcher
and the instant rollback. Changing this clears cached decks.

**Caution:** `profile` can surface unrelated skills; it exists for rollback, not
for tuning.

### `min_skill_score` — Minimum skill score
**number 0–1** · live `0.50` · default `0.50`

Hard gate applied in `match_cards` and `match_candidates_v2`. A pair is included
only when its taxonomy score reaches this value. With the score ladder above:

| Value | What passes |
|---|---|
| `1.00` | exact skill only |
| `0.80` | exact + ancestor |
| `0.65` | exact + ancestor + descendant |
| `0.50` (live) | exact, ancestor, descendant; **siblings excluded** |
| `0.45` | adds siblings (same parent) |
| `0.00` | unrelated cards (do not use) |

Default `0.50` is deliberate: it stops Web Development from matching Python
through the 0.45 sibling score. Lower to `0.45` only if the product wants
adjacent skills in decks. Raising above `0.80` can empty sparse decks.

### `min_final_score` — Minimum final score
**number 0–1** · live `0.35` · default `0.35`

Drops a card whose final score is below this value. Cards mode floors the final
score at the structured bi-encoder score, so an exact pair normally lands around
0.50–0.65. The reranker can produce ~0.09 on short card text, which is why the
floor exists and why `0.50` previously emptied decks. `0` disables the filter;
values above ~0.65 become aggressive.

### `require_discovery_media` — Require discovery media
**boolean** · live `true` · default `true`

When true, a teaching card is served only if the candidate passes
`has_discovery_media`: the teaching notes are complete and the profile has at
least one showcase (or legacy teaching images). This is **per side, not per
card** — one showcase keeps all of that user's teaching cards eligible.

**Important:** the media gate is already part of `side_ready`, which every mode
calls. Setting this to `false` does **not** bypass the showcase requirement; it
only removes a redundant second check. Treat it as an explicit assertion of the
policy, not a switch.

**Caution:** profile mode enforces the same readiness through `side_ready`
regardless of this key.

### `max_per_user` — Maximum cards per person
**integer 1–10** · live `2` · default `2`

Cards mode only. Caps how many cards one person can occupy in a single deck.
A `both` profile can legitimately match on two skills; `2` allows both without
letting one person fill the deck. `1` enforces one card per person; higher values
increase repeat exposure.

### `max_per_skill` — Maximum cards per skill
**integer 1–50** · live `3` · default `3`

Cards mode only. Caps how many candidates for the same skill can appear in one
deck. This is the main diversity control: with six eligible cooking mentors and
`3`, only the top three are shown. Raising it increases choice but lets one
skill dominate; lowering it to `1–2` forces cross-skill variety.

---

## 4. Reciprocal scoring (group: “Reciprocal scoring”)

### `reciprocal_formula` — Reciprocal formula
**enum** · live `geometric_mean` · default `geometric_mean`  
Allowed: `geometric_mean`, `arithmetic_mean`, `weighted_mean`, `harmonic_mean`,
`min`

Combines rerank direction A and B. `geometric_mean` is `sqrt(A × B)` and
penalizes one-sided pairs. `arithmetic_mean` is friendlier to one-sided pairs.
`weighted_mean` is the only formula that reads `rerank_a_weight` and
`rerank_b_weight`. `harmonic_mean` is the strictest; `min` uses the weaker
direction. If direction B was not run, the function uses A alone regardless of
the formula.

### `rerank_a_weight` — Direction A weight
**number 0–10** · live `0.60` · default `0.60`

Weight of direction A in `weighted_mean` only. Ignored by every other formula.
A is “does the viewer want this card?”; B is “does the candidate want the
viewer?”. Higher A favors the viewer's intent.

### `rerank_b_weight` — Direction B weight
**number 0–10** · live `0.40` · default `0.40`

Weight of direction B in `weighted_mean` only. Higher B favors reciprocity.
The weights are normalized by their sum; they do not need to add to 1.

### `max_deck_size` — Deck cap
**integer 1–100** · live `20` · default `20`

Final number of cards returned after exclusions and (in cards mode) diversity.
It caps the deck, not the candidate pool. `candidate_pool_k` controls how many
candidates are considered before rerank.

---

## 5. Retrieval and embeddings (group: “Retrieval & embeddings”)

### `embed_provider` — Embedding provider
**enum** · live `deepinfra` · default `nvidia` · allowed `nvidia | deepinfra`

Selects the embedding provider. The preset owns the endpoint, model, and secret
(`NIM_API_KEY` or `DEEPINFRA_API_KEY`). Publishing rewrites `embedding_model`,
`embedding_api`, and `inference_provider`. Changing the provider changes the
vector space; old vectors are ignored by model name and are purged when the
model changes. Rebuild vectors after switching.

### `rerank_provider` — Rerank provider
**enum** · live `nvidia` · default `nvidia` · allowed `nvidia | deepinfra`

Selects the reranker. Independent from the embedding provider (production uses
DeepInfra embeddings and NVIDIA rerank). Publishing rewrites `rerank_model` and
`rerank_api`. A provider without a configured secret produces a warning in the
panel; runtime falls back or degrades to `basic_bi`.

### `candidate_pool_k` — Candidate pool
**integer 5–500** · live `50` · default `50`

How many candidates enter rerank. Higher values improve recall but increase
rerank cost and cold-deck latency. Cards mode requests `3 × K` card rows from
SQL and slices to `K`. `20–50` is a reasonable production range.

### `embedding_dim` — Embedding dimensions
**integer 64–4096** · live `1024` · default `1024`

Dimensions passed to the provider. **Keep 1024**: the database columns are
`vector(1024)`, and a different provider output length will fail to insert or
compare. Changing providers normally keeps 1024.

### `embedding_weights` — Embedding weights
**JSON object** · live `{"bio":0,"skills":0.7,"context":0.3}` · default same

Weights for the bi-encoder score: `skills` and `context` are used. `bio` is
currently **ignored** by both `get-matches` and the possible-match worker. Values
need not sum to 1; they are a weighted sum. Raising `context` favors shared
language/availability/styles; raising `skills` favors exact skill similarity.

### `calibration` — Calibration
**string** · live `sigmoid` · **Reserved / no effect**

Stored for compatibility. The runtime hardcodes `sigmoid` for rerank logits.
Changing this value changes nothing.

---

## 6. Rerank throughput (group: “Rerank throughput”)

### `rerank_fallback_provider` — Rerank fallback
**enum** · live `deepinfra` · default `deepinfra` · allowed `none | nvidia | deepinfra`

Second provider tried when a rerank call fails. `none` disables the fallback; a
failing primary then drops to `basic_bi`. A fallback equal to the primary is
stored as `none` by the publisher.

### `rerank_failure_threshold` — Circuit failure threshold
**integer 1–20** · live `3` · default `3`

Consecutive primary failures that open the rerank circuit breaker. While open,
direction A skips the primary and goes straight to the fallback/`basic_bi`.
Only direction A probes the breaker; direction B timeouts do not open it.

### `rerank_cooldown_seconds` — Circuit cooldown
**integer 10–600** · live `60` · default `60`

How long the breaker stays open before a probe. Longer values protect the
provider but extend degraded ranking after an outage.

### `rerank_b_limit` — Direction-B limit
**integer 0–500** · live `10` · default `10`

How many top direction-A candidates also get a direction-B rerank. `0` disables
direction B entirely and halves rerank cost; the deck then ranks on A alone.
Higher values improve reciprocity precision but cost one provider call per
candidate.

### `rerank_b_concurrency` — Direction-B concurrency
**integer 1–50** · live `10` · default `10`

Parallel direction-B calls. Higher values finish sooner but raise provider
burst load. B is also bounded by the remaining `rerank_budget_ms`.

### `rerank_budget_ms` — Total rerank budget
**integer 500–40000** · live `9000` · default `9000`

Wall-clock budget for the rerank phase (A + B). When exhausted, B stops and the
remaining candidates keep A-only scores. This is the main control for the
client's 45-second deck budget.

### `rerank_a_timeout_ms` — Direction-A timeout
**integer 500–40000** · live `7000` · default `7000`

Per-call timeout for the batched direction-A rerank. Must fit inside the total
budget.

### `rerank_b_timeout_ms` — Direction-B timeout
**integer 250–40000** · live `4000` · default `4000`

Per-call timeout for each direction-B rerank, also capped by the remaining total
budget. Lower values protect latency; too low leaves B scores missing, and the
final score falls back to A or the bi score.

### `rerank_template` — Rerank template
**JSON object** · live `{"include_bio":false,"include_styles":true,"include_languages":true,"include_secondary":true,"max_details_chars":500,"include_availability":true}` · **Reserved / no effect**

Stored for a future prompt builder. The current functions build rerank text
directly in `get-matches`/`cards.ts`; no code reads this key.

---

## 7. Rate limits (group: “Rate limits”)

### `get_matches_rate_limit` — Deck requests per user
**integer 1–10000** · live `60` · default `60`

Maximum `get-matches` calls per user inside the window. On limit, the function
serves a stale cached deck when one exists; otherwise it returns `429` with a
retry hint. The local experiment used 4 calls per observer without approaching
this limit.

### `get_matches_rate_window_seconds` — Rate window
**integer 60–86400** · live `3600` · default `3600`

Window for the deck limit. `3600` = 60 requests per rolling hour per user.

---

## 8. Decision and moderation (group: “Decision & moderation”)

These keys tune custom-skill classification (`classify-skill`) and note
moderation (`moderate-notes`). They do not affect deck ranking.

### `decision_model` — Decision model
**string** · live `typesafe/jev-1.13` · default `typesafe/jev-1.13`

OpenRouter model used for skill classification and note moderation. Changing it
changes cost and verdict quality; `decision_prompt_version` only labels the
result in logs.

### `decision_prompt_version` — Prompt version label
**string** · live `v1` · default `v1`

Recorded on every moderation log row. The prompt text itself is in code and
`moderation_guidelines`; this is a traceability label, not a switch.

### `decision_confidence_threshold` — Auto-approve confidence
**number 0–1** · live `0.80` · default `0.80`

Confidence needed to attach a semantic match or auto-approve a newly created
skill node. Below it, a new node is created as `pending` for admin review.
Higher values are stricter and reduce auto-approvals.

### `decision_min_skill` — Minimum skill confidence
**number 0–1** · live `0.60` · default `0.60`

If the model's skill score is below this, the submission is rejected as
`invalid_skill`.

### `decision_min_safety` — Minimum safety confidence
**number 0–1** · live `0.60` · default `0.60`

If the safety score is below this, the submission is rejected as `safety`.
Safety rejection wins over skill rejection.

### `decision_cardinality_mode` — Decision cardinality mode
**string** · live `flat` · **Reserved / no effect**

No code reads this key. It is a leftover decision-pipeline knob.

### `decision_valid_skill_floor` — Valid-skill floor
**number 0–1** · live `0.60` · **Reserved / no effect**

No code reads this key. `decision_min_skill` is the active floor.

### `note_min_relevance` — Note relevance floor
**number 0–1** · live `0.50` · default `0.50` (code fallback 0.60)

A note is approved only if its relevance score reaches this. Notes below it are
rejected with `note_rejected_low_relevance` and the author is notified.

### `note_min_safety` — Note safety floor
**number 0–1** · live `0.60` · default `0.60`

Safety floor for a note. All note gates are combined with AND.

### `note_min_value` — Note value floor
**number 0–1** · live `0.40` · default `0.40`

Minimum “value” score for a note, used alongside relevance and safety. Notes
below it are rejected with `note_rejected_low_value`. This key lives under
“Other keys” in the panel, not the moderation group.

### `moderation_guidelines` — Moderation guidelines
**long text** · live: the production skill-relevancy + safety prompt

The full instruction text sent to the decision model. It defines what counts as a
teachable skill (practical, creative, cultural, everyday) and what is rejected
(one-off actions, products, brands, people; unsafe or illegal content). Editing
it changes verdicts immediately on the next classification call.

---

## 9. Other keys (group: “Other keys”)

These are visible and editable but not in a named group.

### `worker_url` — Moderation worker URL
**URL** · live `https://yjcrfgvenilptrnudvcb.supabase.co/functions/v1/moderate-notes`

Target of the `pg_cron` note-moderation job. It must be the deployed
`moderate-notes` function URL. Changing it to a wrong host stops note moderation
silently (the cron call fails).

### Possible-match notifications (16 keys)

These control the “possible match” notification pipeline. It runs in SQL, on a
per-minute cron, and is separate from the For You deck.

| Key | Type | Live | Default | Effect |
|---|---|---|---|---|
| `possible_match_enabled` | boolean | `true` | `true` | Master switch. `false` stops claiming and emitting jobs. |
| `possible_match_mode` | enum | `live` | `shadow` | `off`/`shadow` records events without notifications; `live` sends them. |
| `possible_match_debounce_seconds` | integer | `45` | `45` | Coalesces repeated profile/skill/showcase edits into one job. |
| `possible_match_jobs_per_run` | integer | `20` | `20` | Jobs claimed per cron invocation (cron runs every minute). |
| `possible_match_recipients_per_job` | integer | `100` | `100` | Maximum recipients notified for one candidate. |
| `possible_match_recall_k` | integer | `200` | `200` | Nearest viewers retrieved per embedding direction. |
| `possible_match_min_score` | number | `0.12` | `0.12` | Minimum cosine score for an embedding-based match. |
| `possible_match_fallback_score` | number | `0.12` | `0.12` | Score assigned to an exact skill-overlap fallback pair. Keep it `>= min_score` or fallback pairs are suppressed. |
| `possible_match_skill_fallback` | boolean | `true` | `true` | Allow exact skill overlap when embeddings are absent. |
| `possible_match_cooldown_days` | integer | `60` | `60` | Suppress the same recipient/candidate pair for this many days. |
| `possible_match_daily_cap` | integer | `3` | `3` | Maximum possible matches per recipient per rolling 24 h. |
| `possible_match_weekly_cap` | integer | `10` | `10` | Maximum per recipient per rolling 7 days. |
| `possible_match_max_attempts` | integer | `5` | `5` | Failed attempts before a job is marked failed; retries use exponential backoff. |
| `possible_match_job_lock_minutes` | integer | `5` | `5` | Reaps a stale `processing` job after this many minutes. |
| `possible_match_inactive_days` | integer | `0` | `0` | Skip recipients unseen for N days; `0` disables the filter. |
| `possible_match_retention_days` | integer | `90` | `90` | Deletes read possible-match notifications after N days. |

Recommended tuning: keep `mode=live`, `min_score` and `fallback_score` equal,
`daily_cap=3`, `weekly_cap=10`, and `cooldown_days=60`. Raise caps only with
moderation coverage; lower `jobs_per_run` if the cron overlaps with peak traffic.

---

## 10. Derived keys (hidden in the editor)

These are rewritten by the publisher from the provider presets. Edit the
provider keys instead.

| Key | Live | Source |
|---|---|---|
| `inference_provider` | `deepinfra` | Mirrors the embedding provider for legacy readers |
| `embedding_model` | `nvidia/Nemotron-3.5-Embed-8B-BF16` | `embed_provider` preset |
| `embedding_api` | `https://api.deepinfra.com/v1/openai/embeddings` | preset |
| `rerank_model` | `nvidia/nemotron-3.5-rerank-8b` | `rerank_provider` preset |
| `rerank_api` | `https://ai.api.nvidia.com/v1/retrieval/…/reranking` | preset |

`__revision` is internal and cannot be edited.

---

## 11. Operating recipes

**Conservative / high precision**
`matcher_mode=cards`, `min_skill_score=0.50`, `min_final_score=0.40`,
`max_per_skill=2`, `max_per_user=1`, `candidate_pool_k=30`,
`rerank_b_limit=6`.

**Balanced (current)**
`cards`, `0.50`, `0.35`, `3`, `2`, `50`, `10`.

**High recall / sparse supply**
`min_skill_score=0.45` (allows siblings), `min_final_score=0.25`,
`max_per_skill=5`, `candidate_pool_k=100`, `rerank_b_limit=20`.

**Cost reduction**
`rerank_b_limit=0` (drops direction B), `candidate_pool_k=30`,
`rerank_budget_ms=5000`, `rerank_b_timeout_ms=2500`.

**Rollback**
Set `matcher_mode=profile` and publish. Restores the legacy whole-profile deck
immediately and clears caches.

---

## 12. Change checklist

1. Change one group at a time.
2. Save a draft with a note, then publish with a reason.
3. Verify **Card matcher health**: mode, card vector coverage, cache rows.
4. Open For You on two accounts with different skills and compare decks.
5. Check `possible_match` notifications if the change touches profile/skill
   readiness.
6. Watch cold-deck latency and the rerank provider circuit after a threshold or
   pool change.
7. Roll back with the published version if decks empty or latency spikes.

## 13. First-response checks

| Symptom | Likely cause | First check |
|---|---|---|
| Deck empty or very short | Threshold or supply gate too tight | `min_final_score`, `min_skill_score`, then whether candidates pass `side_ready` (notes plus one showcase) |
| Same person repeats in a deck | Diversity caps too loose | Lower `max_per_user` to `1` and `max_per_skill` to `2`, then publish |
| Cold deck over 45 s | Rerank budget, pool, or a tripped breaker | `rerank_budget_ms`, `candidate_pool_k`, and the rerank circuit state |
| Deck ignores a profile edit | Cached deck still valid | `match_cache_v2` rows for the user; publish or wait for the timestamp to change |
| Notes never go public | Worker URL or cron stopped | `worker_url`, the `pg_cron` note job, and the three `note_min_*` floors |
| Possible matches stop arriving | Mode, caps, or cooldown | `possible_match_mode = live`, then daily/weekly caps and `possible_match_cooldown_days` |

---

## Appendix — quick reference

| Key | Type | Live | Default | Status |
|---|---|---|---|---|
| `matcher_mode` | enum | `cards` | `profile` | active |
| `min_skill_score` | 0–1 | `0.50` | `0.50` | active |
| `min_final_score` | 0–1 | `0.35` | `0.35` | active |
| `require_discovery_media` | bool | `true` | `true` | redundant with side_ready |
| `max_per_user` | 1–10 | `2` | `2` | active (cards) |
| `max_per_skill` | 1–50 | `3` | `3` | active (cards) |
| `reciprocal_formula` | enum | `geometric_mean` | `geometric_mean` | active |
| `rerank_a_weight` | 0–10 | `0.60` | `0.60` | weighted mean only |
| `rerank_b_weight` | 0–10 | `0.40` | `0.40` | weighted mean only |
| `max_deck_size` | 1–100 | `20` | `20` | active |
| `embed_provider` | enum | `deepinfra` | `nvidia` | active |
| `rerank_provider` | enum | `nvidia` | `nvidia` | active |
| `candidate_pool_k` | 5–500 | `50` | `50` | active |
| `embedding_dim` | 64–4096 | `1024` | `1024` | keep 1024 |
| `embedding_weights` | JSON | `{bio:0, skills:.7, context:.3}` | same | active (bio ignored) |
| `calibration` | string | `sigmoid` | `sigmoid` | **reserved** |
| `rerank_fallback_provider` | enum | `deepinfra` | `deepinfra` | active |
| `rerank_failure_threshold` | 1–20 | `3` | `3` | active |
| `rerank_cooldown_seconds` | 10–600 | `60` | `60` | active |
| `rerank_b_limit` | 0–500 | `10` | `10` | active |
| `rerank_b_concurrency` | 1–50 | `10` | `10` | active |
| `rerank_budget_ms` | 500–40000 | `9000` | `9000` | active |
| `rerank_a_timeout_ms` | 500–40000 | `7000` | `7000` | active |
| `rerank_b_timeout_ms` | 250–40000 | `4000` | `4000` | active |
| `rerank_template` | JSON | `{…}` | same | **reserved** |
| `get_matches_rate_limit` | 1–10000 | `60` | `60` | active |
| `get_matches_rate_window_seconds` | 60–86400 | `3600` | `3600` | active |
| `decision_model` | string | `typesafe/jev-1.13` | same | active |
| `decision_prompt_version` | string | `v1` | `v1` | log label |
| `decision_confidence_threshold` | 0–1 | `0.80` | `0.80` | active |
| `decision_min_skill` | 0–1 | `0.60` | `0.60` | active |
| `decision_min_safety` | 0–1 | `0.60` | `0.60` | active |
| `decision_cardinality_mode` | string | `flat` | `flat` | **reserved** |
| `decision_valid_skill_floor` | 0–1 | `0.60` | `0.60` | **reserved** |
| `note_min_relevance` | 0–1 | `0.50` | `0.50` | active |
| `note_min_safety` | 0–1 | `0.60` | `0.60` | active |
| `note_min_value` | 0–1 | `0.40` | `0.40` | active |
| `moderation_guidelines` | text | production prompt | — | active |
| `worker_url` | URL | moderate-notes function | — | active |
| `possible_match_enabled` | bool | `true` | `true` | active |
| `possible_match_mode` | enum | `live` | `shadow` | active |
| `possible_match_debounce_seconds` | int | `45` | `45` | active |
| `possible_match_jobs_per_run` | int | `20` | `20` | active |
| `possible_match_recipients_per_job` | int | `100` | `100` | active |
| `possible_match_recall_k` | int | `200` | `200` | active |
| `possible_match_min_score` | num | `0.12` | `0.12` | active |
| `possible_match_fallback_score` | num | `0.12` | `0.12` | active |
| `possible_match_skill_fallback` | bool | `true` | `true` | active |
| `possible_match_cooldown_days` | int | `60` | `60` | active |
| `possible_match_daily_cap` | int | `3` | `3` | active |
| `possible_match_weekly_cap` | int | `10` | `10` | active |
| `possible_match_max_attempts` | int | `5` | `5` | active |
| `possible_match_job_lock_minutes` | int | `5` | `5` | active |
| `possible_match_inactive_days` | int | `0` | `0` | active |
| `possible_match_retention_days` | int | `90` | `90` | active |
| `inference_provider` | derived | `deepinfra` | — | rewritten |
| `embedding_model` | derived | DeepInfra Nemotron embed | — | rewritten |
| `embedding_api` | derived | DeepInfra endpoint | — | rewritten |
| `rerank_model` | derived | NVIDIA Nemotron rerank | — | rewritten |
| `rerank_api` | derived | NVIDIA endpoint | — | rewritten |
| `__revision` | internal | `343` | — | automatic |

