# PalTuro Matching Variables

Status: design reference for the future admin panel. The taxonomy roles
(`category` / `skill` / `focus`) are live; the structured scoring parameters
below are the contract the matcher will read.

## Model in one paragraph

A node is selectable only when `kind = 'skill'`. Categories group skills and
may nest; focus nodes refine a skill (a dish, framework, style). Depth is a
consequence of tree position, not a role. Users store `skill_id` (a skill) and
optionally a focus. The matcher is text/embedding-based today; the structured
score below is the precision layer that makes exact skills outrank siblings.

## Score formula (multiplicative)

```
skill   = best_skill_pair(seeker_skills, candidate_skills)   // 0..1
context = weighted_context(...)                              // 0..1
bi      = w_skills * skills_sim + w_context * context_sim    // 0..1
rerank  = reciprocal(rerank_a, rerank_b)                     // 0..1

final = rerank * (final_base
                  + final_skill_boost * skill
                  + final_context_boost * context)

final = clamp(final, final_min_multiplier, final_max_multiplier)
if (skill >= 0.99) final += exact_match_floor
```

Defaults: `final_base = 0.75`, `final_skill_boost = 0.50`,
`final_context_boost = 0.15`, `exact_match_floor = 0.05`.

For You policy: relevance first. Siblings are not force-included; they rank
only when their final score earns it. `exploration_quota = 0`.

## Variables

### A. Retrieval

| Key | Default | Range | Effect |
|---|---|---|---|
| `candidate_pool_k` | 50 | 10–200 | Candidates entering rerank |
| `vector_weight_skills` | 0.7 | 0–1 | Bi-encoder skills weight |
| `vector_weight_context` | 0.3 | 0–1 | Bi-encoder context weight |
| `exact_skill_quota` | 20 | 0–50 | Reserved recall slots for exact skill matches |
| `focus_quota` | 10 | 0–30 | Reserved recall slots for focus matches |
| `sibling_quota` | 10 | 0–30 | Reserved recall slots for same-category skills |
| `fallback_limit` | 200 | 0–500 | Skills-only fallback set |
| `require_discovery_media` | true | bool | Exclude profiles without showcase media |
| `require_onboarding` | true | bool | Exclude incomplete profiles |
| `exclude_connections` | true | bool | Exclude pending/accepted connections |
| `exclude_blocks` | true | bool | Exclude blocked pairs |
| `min_bi_score` | 0.0 | 0–1 | Optional retrieval floor |

Quotas only guarantee recall; they never reserve final ranking slots.

### B. Structured skill score

| Key | Default | Example |
|---|---|---|
| `skill_exact` | 1.00 | Python ↔ Python |
| `skill_exact_no_focus` | 0.90 | seeker Python+Django ↔ Python (no focus) |
| `skill_exact_other_focus` | 0.85 | seeker Python+Django ↔ Python+Flask |
| `skill_general_to_specific` | 0.55 | seeker General Programming ↔ Python |
| `skill_specific_to_general` | 0.50 | seeker Python ↔ General Programming |
| `skill_sibling` | 0.45 | Python ↔ C# |
| `skill_adjacent_category` | 0.40 | Python ↔ Web Development (if adjacent) |
| `skill_tree_child` | 0.80 | future skill nesting: child skill |
| `skill_tree_parent` | 0.65 | future: parent skill |
| `skill_tree_cousin` | 0.20 | future: cousin |
| `skill_unrelated` | 0.00 | Python ↔ Cooking |
| `skill_second_match_bonus` | 0.05 | second matching skill |
| `skill_cap` | 1.00 | clamp |

Aggregation: `max` over all seeker/candidate pairs plus the second-match
bonus, clamped. Never sum (a candidate with many skills must not dominate).

`is_general` is a data flag on generalist skills (General Programming), not a
depth inference.

### C. Context and preferences

| Key | Default | Effect |
|---|---|---|
| `context_language_weight` | 0.35 | Shared language |
| `context_style_weight` | 0.30 | Seeker learning style ↔ candidate teaching style (and reverse) |
| `context_availability_weight` | 0.25 | Day overlap |
| `context_timezone_weight` | 0.10 | Timezone proximity |
| `context_category_weight` | 0.0 | Shared category (optional) |
| `context_note_weight` | 0.0 | Skill note relevance (optional) |
| `style_match_mode` | overlap | `overlap`, `complementary`, `exact` |
| `availability_match_mode` | ratio | `any`, `ratio`, `min_days` |
| `language_match_mode` | any_common | `any_common`, `ratio` |
| `neutral_score_when_missing` | 0.5 | Don't punish empty profiles |
| `timezone_max_offset_hours` | 6 | Beyond this, 0 |

### D. Reranker

| Key | Default |
|---|---|
| `rerank_enabled` | true |
| `rerank_model` | `nvidia/nemotron-3.5-rerank-8b` |
| `rerank_api` | model-specific URL |
| `rerank_a_weight` | 0.6 |
| `rerank_b_weight` | 0.4 |
| `reciprocal_formula` | geometric_mean |
| `calibration` | sigmoid |
| `rerank_timeout_ms` | 7000 |
| `rerank_budget_ms` | 9000 |
| `rerank_b_limit` | 10 |
| `rerank_b_concurrency` | 10 |
| `rerank_b_timeout_ms` | 4000 |
| `basic_bi_fallback` | true |

### E. Final score

| Key | Default | Effect |
|---|---|---|
| `final_base` | 0.75 | Multiplier floor |
| `final_skill_boost` | 0.50 | Skill score multiplier |
| `final_context_boost` | 0.15 | Context score multiplier |
| `final_min_multiplier` | 0.75 | Clamp |
| `final_max_multiplier` | 1.30 | Clamp |
| `exact_match_floor` | 0.05 | Additive protection for exact matches |
| `min_final_score` | 0.0 | Optional display threshold |
| `min_skill_score` | 0.0 | Optional inclusion threshold |
| `tie_breaker` | rerank | `rerank`, `online`, `last_seen`, `usage`, `random` |

### F. Diversity and exposure

| Key | Default | Effect |
|---|---|---|
| `exploration_quota` | 0 | For You: no special inclusion |
| `max_per_category` | 5 | Avoid one category dominating |
| `max_per_skill` | 3 | Avoid one skill dominating |
| `repeat_skill_penalty` | 0.05 | Discourage duplicate skill cards |
| `online_boost` | 0.0 | Optional presence boost |
| `new_user_boost` | 0.0 | Optional cold-start boost |
| `exposure_cap_per_candidate` | 0 | Optional fairness cap |

### G. Cache and versioning

| Key | Default |
|---|---|
| `cache_ttl_minutes` | 10 |
| `invalidate_on_profile_change` | true |
| `invalidate_on_taxonomy_change` | true |
| `invalidate_on_config_change` | true |
| `config_revision` | auto |
| `taxonomy_version` | auto |

Both revisions belong in `match_cache` and the client deck cache key.

## Logging and measurement

Per result: `candidate_id`, `rank`, `bi_score`, `skill_score`,
`context_score`, `rerank_a`, `rerank_b`, `reciprocal`, `final`,
`matched_skill_id`, `matched_focus_id`, `mode`, `config_revision`,
`taxonomy_version`.

Offline metrics: precision@k, NDCG, exact-match recall, sibling rate, coverage.
Online metrics: request rate, reply rate, acceptance, unmatch/report rate.
A/B: `config_revision` is the experiment key.

## Admin panel requirements

- Typed keys (`number`, `boolean`, `enum`, `json`) with defaults, min/max,
  description, and group.
- Validation: scores 0–1; `skill_exact` must be the maximum; weights
  non-negative; multipliers within clamps; `final_base + boosts` sane.
- Versioned: every save bumps `config_revision`, writes an audit row, and
  invalidates caches.
- Preview: run a draft config against a sample seeker and show before/after.
- Rollback: restore a previous revision.
- The Edge Function reads config and passes a JSONB `p_params` into
  `match_candidates`, so weight changes do not need a SQL deploy.

## Edge cases

- Missing preferences → `neutral_score_when_missing`, never 0.
- Focus absent → no penalty; exact skill still 1.0.
- Multiple skills → max + second bonus; never sum.
- Role asymmetry → seeker learn ↔ candidate teach for mentor targets, and the
  reverse for learner targets.
- Rejected/retired skills → excluded from discovery and passages; classifier-
  accepted user submissions are auto-approved and marked `auto_approved` so the
  admin panel can curate them later.
- Rename/merge → IDs stable; taxonomy version invalidates caches; passages
  re-embed.
- Missing embeddings → structured path still works.
- Reranker contradiction → exact-match floor must survive a stronger sibling
  bio; cover with a fixture.
- Config mistakes → clamp and validate; a sibling can never outscore an exact
  match.
- Cross-listing (future) → take the best common category; never double count.
- Multiple focuses (future) → best pair + second-focus bonus.

## Test fixture

Seeker wants Python. Candidates: Python, Python+Django, General Programming,
C# Programming, Web Development, Filipino Cooking. Assert the order exact >
focus > general > sibling > unrelated, with and without embeddings, and with
the reranker disabled.
