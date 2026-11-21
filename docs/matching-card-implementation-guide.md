# Card-level matching â€” implementation guide

Companion to `matching-card-rework-plan.md`. This is the build guide: exact
files, SQL, function signatures, client changes, tests, and rollout order.

Everything is **additive and flag-gated**. The current profile-level path stays
deployed and working until Phase 4.

## Implementation status (local, not applied)

| Phase | Code | State |
|---|---|---|
| 0 | `supabase/migrations/20261123000100_card_pair_score.sql`, `matcher_mode=gated`, matched skill in the response, `preferSkillId` in the client | written |
| 1 | `supabase/migrations/20261124000100_skill_cards.sql`, `ensureFreshCardEmbeddings` | written |
| 2 | `supabase/migrations/20261125000100_match_cards.sql`, `get-matches/cards.ts`, `match_cache_v2` | written |
| 3 | `Person.cardId/skillKind`, deck keys, matched-skill rendering, card badge | written |
| 4 | cleanup | deferred (destructive) |

Nothing has been applied to the database, deployed, or pushed. `supabase/schema.sql`
has **not** been regenerated; the migrations are authoritative.


---

## 0. Ground rules

- **Backward compatible responses.** Every new field is additive. Old clients
  ignore extras; never rename or remove `user_id`, `role`, `compatibility`,
  `pipeline`.
- **Nothing destructive until Phase 4.** New tables/columns only. No column
  drops, no renames, no data deletes.
- **Flag first.** `pipeline_config.matcher_mode` = `profile` (default) |
  `cards`. Read it in `get-matches`; rollback is a config flip + redeploy-free.
- **Card identity is `user_skills.id`.** Do not create a parallel card table
  yet. `user_skills` already has `(user_id, skill_id, kind)` uniqueness, note
  moderation, and FK cascades. Add columns to it; a view/table can come later
  if card-only fields grow.
- **Showcases bind by `skill_id`, but the binding is unreliable today.**
  `set_skill_showcases` derives `skill_id` from a caption match, so many rows
  have `skill_id = null`. Discovery therefore gates media **per side** via
  `has_discovery_media` / `side_ready`; do not hard-gate a card on
  `skill_showcases.skill_id` until the writer links showcases explicitly.

### Locked defaults (change in one place: `pipeline_config`)

| Key | Default | Used by |
|---|---|---|
| `matcher_mode` | `profile` | `get-matches` (`profile` \| `gated` \| `cards`) |
| `min_skill_score` | `0.50` | card gate |
| `min_final_score` | `0.35` | deck filter |
| `require_discovery_media` | `true` | teach cards |
| `max_per_user` | `2` | diversity pass |
| `max_per_skill` | `3` | diversity pass |
| `skill_exact` | `1.00` | `skill_pair_score` |
| `skill_tree_child` | `0.80` | `skill_pair_score` |
| `skill_tree_parent` | `0.65` | `skill_pair_score` |
| `skill_sibling` | `0.45` | `skill_pair_score` |
| `skill_unrelated` | `0.00` | `skill_pair_score` |

`matching-variables.md` already documents the rest; keep that file as the
source of truth for tunables.

---

# Phase 0 â€” stopgap (1â€“2 days)

Goal: no For You card without a compatible skill pair, and the card shows the
skill that actually matched. No client-breaking change.

## 0.1 Compatibility function

New migration `supabase/migrations/20261123000100_card_pair_score.sql`:

```sql
create or replace function public.skill_pair_score(
  a extensions.ltree,
  b extensions.ltree
) returns real
language sql
immutable
set search_path = public, extensions
as $$
  select case
    when a is null or b is null then 0::real
    when a = b then 1.00::real
    when a @> b then 0.80::real       -- a is an ancestor of b
    when b @> a then 0.65::real       -- a is a descendant of b
    when nlevel(a) > 1 and nlevel(b) > 1
         and subpath(a, 0, nlevel(a) - 1) = subpath(b, 0, nlevel(b) - 1)
      then 0.45::real                 -- siblings
    else 0::real
  end
$$;

revoke all on function public.skill_pair_score(extensions.ltree, extensions.ltree)
  from public, anon;
grant execute on function public.skill_pair_score(extensions.ltree, extensions.ltree)
  to authenticated, service_role;
```

## 0.2 Gated retrieval function

New function `match_candidates_v2` (do **not** replace `match_candidates`; keeping
it lets you flip back):

```sql
create or replace function public.match_candidates_v2(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_w_skills real,
  p_w_context real,
  p_min_skill real default 0.50,
  p_require_media boolean default true
) returns table (
  candidate_id uuid,
  bi_score real,
  skill_score real,
  card_id uuid,
  skill_id uuid,
  skill_name text,
  skill_path text,
  skill_kind public.skill_kind
)
language sql
stable
security definer
set search_path = public, extensions
as $$
with seeker as (
  select case when p_target = 'mentor'
              then 'learner'::public.embed_role
              else 'mentor'::public.embed_role end as s_role
),
target_kind as (
  select case when p_target = 'mentor'
              then 'teach'::public.skill_kind
              else 'learn'::public.skill_kind end as k
),
my_cards as (
  select n.path, us.kind
  from public.user_skills us
  join public.skill_nodes n on n.id = us.skill_id
  where us.user_id = p_user
    and us.kind = case when p_target = 'mentor'
                       then 'learn'::public.skill_kind
                       else 'teach'::public.skill_kind end
),
blocked as (
  select blocked_id as uid from public.blocks where blocker_id = p_user
  union
  select blocker_id as uid from public.blocks where blocked_id = p_user
),
pairs as (
  select c.user_id as candidate_id,
         c.id as card_id,
         c.skill_id,
         n.name as skill_name,
         n.path::text as skill_path,
         c.kind as skill_kind,
         max(public.skill_pair_score(m.path, n.path))::real as skill_score
  from public.user_skills c
  join public.skill_nodes n on n.id = c.skill_id
  join public.profiles p on p.id = c.user_id and p.has_completed_onboarding
  join my_cards m
    on public.skill_pair_score(m.path, n.path) >= p_min_skill
  cross join target_kind tk
  where c.kind = tk.k
    and c.user_id <> p_user
    and not exists (select 1 from blocked b where b.uid = c.user_id)
    and (
      not p_require_media
      or c.kind <> 'teach'::public.skill_kind
      or exists (
        select 1 from public.skill_showcases sc
        where sc.user_id = c.user_id and sc.skill_id = c.skill_id
      )
    )
  group by c.user_id, c.id, c.skill_id, n.name, n.path, c.kind
),
s_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query'
    and role = (select s_role from seeker)
    and field_group = 'skills'::public.embed_field_group
),
c_me as (
  select embedding from public.profile_embeddings
  where user_id = p_user and input_type = 'query'
    and role = (select s_role from seeker)
    and field_group = 'context'::public.embed_field_group
),
s_sc as (
  select e.user_id, (1 - extensions.cosine_distance(s_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join s_me
  where e.role = p_target and e.input_type = 'passage'
    and e.field_group = 'skills'::public.embed_field_group
),
c_sc as (
  select e.user_id, (1 - extensions.cosine_distance(c_me.embedding, e.embedding)) as sim
  from public.profile_embeddings e cross join c_me
  where e.role = p_target and e.input_type = 'passage'
    and e.field_group = 'context'::public.embed_field_group
),
best as (
  select distinct on (p.candidate_id)
    p.candidate_id, p.card_id, p.skill_id, p.skill_name, p.skill_path,
    p.skill_kind, p.skill_score
  from pairs p
  order by p.candidate_id, p.skill_score desc, p.skill_path
)
select b.candidate_id,
       (p_w_skills * coalesce(s_sc.sim, 0)
        + p_w_context * coalesce(c_sc.sim, 0))::real as bi_score,
       b.skill_score, b.card_id, b.skill_id, b.skill_name, b.skill_path, b.skill_kind
from best b
left join s_sc on s_sc.user_id = b.candidate_id
left join c_sc on c_sc.user_id = b.candidate_id
where coalesce(auth.role(), '') = 'service_role' or p_user = auth.uid()
order by 2 desc
limit p_limit;
$$;

revoke all on function public.match_candidates_v2(
  uuid, public.embed_role, integer, real, real, real, boolean
) from public, anon;
grant execute on function public.match_candidates_v2(
  uuid, public.embed_role, integer, real, real, real, boolean
) to authenticated, service_role;
```

Notes:

- The arbitrary 200-user fallback is gone. If the gate yields nobody, the deck
  is empty â€” that is correct.
- The shipped migration also mirrors the production gates
  (`side_ready`, blocks, connections, reports, model-aware vectors) from
  `20261121000800` / `20261121000300`; the snippet above omits them for
  readability. Keep those gates when editing.
- `distinct on` keeps the best card per person for **Phase 0** (the deck is
  still one card per person). Phase 2 removes this.
- `p_require_media` defaults `true` for teach cards.

## 0.3 `get-matches` changes

In `supabase/functions/get-matches/index.ts`:

1. Add config fields in `_shared/pipeline.ts` (`getConfig`):

```ts
matcherMode: unstr(cfg.matcher_mode, "profile"),
minSkillScore: numIn(cfg.min_skill_score, 0.50, 0, 1),
minFinalScore: numIn(cfg.min_final_score, 0.35, 0, 1),
requireDiscoveryMedia: cfg.require_discovery_media !== false,
maxPerUser: intIn(cfg.max_per_user, 2, 1, 10),
maxPerSkill: intIn(cfg.max_per_skill, 3, 1, 50),
```

Add them to the `PipelineCfg` interface and the return object.

2. Candidate call becomes conditional:

```ts
const rpcName = cfg.matcherMode === "cards"
  ? "match_candidates_v2"
  : "match_candidates";

const { data: cands, error: candErr } = await admin.rpc(rpcName, {
  p_user: user.id,
  p_target: targetRole,
  p_limit: cfg.topK,
  p_w_skills: cfg.wSkills,
  p_w_context: cfg.wContext,
  ...(cfg.matcherMode === "cards"
    ? {
        p_min_skill: cfg.minSkillScore,
        p_require_media: cfg.requireDiscoveryMedia,
      }
    : {}),
});
```

3. Types: `candidate_id`, `bi_score`, and optional `card_id`, `skill_id`,
   `skill_name`, `skill_path`, `skill_kind`, `skill_score`.

4. Filter before rerank (Phase 0 only; Phase 2 has card pools):

```ts
const candidates = (cands ?? []).filter((c) =>
  cfg.matcherMode === "cards"
    ? Number(c.skill_score ?? 0) >= cfg.minSkillScore
    : true
);
```

5. After `scored.sort(...)` and before `slice`, apply the final threshold and
   diversity:

```ts
const cleared = ranked.filter((s) =>
  cfg.matcherMode === "cards"
    ? s.calibrated_score >= cfg.minFinalScore
    : true
);
```

(By Phase 2 `max_per_user` is applied per card; Phase 0 keeps one per user.)

6. Response item adds the matched skill:

```ts
const card = cardById.get(s.candidate_id); // Map built from candidates
return {
  user_id: s.candidate_id,
  rank: s.rank,
  display_name: p.name,
  role: p.role,
  compatibility: s.calibrated_score,
  bi_score: s.bi_score,
  pipeline: mode,
  ...(card
    ? {
        card_id: card.card_id,
        skill_id: card.skill_id,
        skill_name: card.skill_name,
        skill_path: card.skill_path,
        skill_kind: card.skill_kind,
      }
    : {}),
};
```

7. Cache: write the same extra columns (see Â§2.5). Until the columns exist,
   keep them out of `match_cache` and only return them live.

## 0.4 Client changes

`lib/services/match_api.dart`:

```dart
class MatchLite {
  // existing fieldsâ€¦
  final String? cardId;
  final String? skillId;
  final String? skillName;
  final String? skillPath;
  final String? skillKind;
}
```

Parse them in `getMatches` (`r['card_id'] as String?`, etc.).

`match_api.dart` enrichment: add `preferSkillId` to
`personFromPublicProfileMap` and select the entry whose `path` matches instead
of `preferred.first`:

```dart
final entry = (preferSkillId != null
    ? skillEntries.firstWhere(
        (e) => (e as Map)['path'] == preferSkillId,
        orElse: () => skillEntries.first,
      )
    : skillEntries.first) as Map;
```

Use it in `fetchAndCacheDeck`:

```dart
final person = await getPersonFromPublicProfile(
  m.userId,
  preferRole: asRoleDb,
  preferSkillId: m.skillPath,
);
```

This is the fix for â€œthe card showed a skill that did not matchâ€.

## 0.5 Tests

SQL fixture (local Supabase):

```sql
-- seed: viewer teaches web dev, candidate A learns traditional music,
-- candidate B learns web dev, candidate C teaches web dev without showcase
select * from public.match_candidates_v2(
  '<viewer>', 'learner', 50, 0.7, 0.3, 0.4, true
);
-- expect: only B
```

Dart: widget test that a `Person` enriched from a match with
`skillPath = 'music.traditional'` displays that skill, not the alphabetical
first.

## 0.6 Deploy and verify

```powershell
# migration
npx supabase db push            # or apply the SQL in the dashboard

# functions
powershell -ExecutionPolicy Bypass -File supabase\deploy-functions.ps1

# flip on the gated path for staff first, then the card path
-- insert into pipeline_config (key, value) values ('matcher_mode', '"gated"')
-- on conflict (key) do update set value = excluded.value;
-- later: '"cards"'
```

Verify with the reported pair: the learner wanting Traditional Music must not
appear for the web-dev-only mentor. Roll back by setting `matcher_mode` to
`"profile"`.

---

# Phase 1 â€” schema + card embeddings (4â€“6 days)

## 1.1 Migration

`supabase/migrations/20261124000100_skill_cards.sql`:

```sql
alter table public.user_skills
  add column if not exists visibility text not null default 'discoverable',
  add column if not exists updated_at_visibility timestamptz not null default now();

alter table public.user_skills
  drop constraint if exists user_skills_visibility_check;
alter table public.user_skills
  add constraint user_skills_visibility_check
  check (visibility in ('discoverable', 'paused', 'hidden'));

create index if not exists idx_uskills_discoverable
  on public.user_skills (kind, skill_id)
  where visibility = 'discoverable';

-- Per-card vectors. The card is user_skills.id.
create table if not exists public.card_embeddings (
  card_id uuid not null references public.user_skills(id) on delete cascade,
  input_type text not null default 'passage'
    check (input_type in ('passage', 'query')),
  source_text text not null,
  source_hash text not null,
  model_name text not null,
  embedding extensions.vector(1024) not null,
  updated_at timestamptz not null default now(),
  primary key (card_id, input_type)
);

create index if not exists idx_card_embeddings_hnsw
  on public.card_embeddings
  using hnsw (embedding extensions.vector_cosine_ops);

alter table public.card_embeddings enable row level security;
-- no client policies: service_role only
revoke all on public.card_embeddings from anon, authenticated;
grant all on public.card_embeddings to service_role;
```

Do **not** mass-update `visibility` for existing teach cards. Gate them in the
query (`showcase exists`) so the data stays intact.

## 1.2 Card passages

`build_card_passages(p_card uuid)` returns one row:

```sql
create or replace function public.build_card_passages(p_card uuid)
returns table (source_text text, source_hash text)
language sql
stable
set search_path = public
as $$
  select txt, md5(txt)
  from (
    select
      case us.kind
        when 'teach' then 'Offers to teach: '
        when 'learn' then 'Wants to learn: '
        else 'Skill: '
      end
      || (
        select string_agg(a.name, ' > ' order by a.depth)
        from public.skill_nodes a
        where a.path @> n.path
      )
      || case when us.note_approved and coalesce(us.note, '') <> ''
              then ' - note: ' || us.note else '' end
      as txt
    from public.user_skills us
    join public.skill_nodes n on n.id = us.skill_id
    where us.id = p_card
  ) s
  where btrim(txt) <> '';
$$;
```

Keep `build_profile_passages` only for the two **context** rows (learner and
mentor). Its `skills` rows become dead once Phase 2 ships.

## 1.3 Embedding writer

Extend `ensureFreshEmbeddings` in `_shared/pipeline.ts` with a card path:

1. Query the user's card ids (`user_skills.id`).
2. Read `build_card_passages` for each.
3. Diff against `card_embeddings` on `(card_id, input_type, source_hash,
   model_name)`.
4. Embed the changed texts in batches of `passage` and `query`.
5. Upsert; delete stale hashes for the same card.

`generate-embeddings` already calls `ensureFreshEmbeddings([user.id])` after
profile saves (`ProfileService` â†’ `functions.invoke('generate-embeddings')`), so
no client change is needed.

## 1.4 Backfill

One-off script (service role) â€” or an admin-api action:

```ts
// pseudocode
const { data: users } = await admin
  .from("user_skills")
  .select("user_id")
  .order("user_id");
const ids = [...new Set(users.map((u) => u.user_id))];
for (const batch of chunk(ids, 50)) {
  await ensureFreshEmbeddings(admin, batch, cfg, key);
}
```

Run during low traffic; the rate limiter does not apply to service_role, but
batches keep provider latency predictable. Track `card_embeddings` count vs
`user_skills` count as the completion gauge.

---

# Phase 2 â€” card pipeline (8â€“10 days)

## 2.1 `match_cards`

Signature:

```sql
create or replace function public.match_cards(
  p_user uuid,
  p_target public.embed_role,
  p_limit integer,
  p_min_skill real,
  p_require_media boolean,
  p_w_skills real,
  p_w_context real
) returns table (
  candidate_id uuid,
  card_id uuid,
  skill_id uuid,
  skill_name text,
  skill_path text,
  skill_kind public.skill_kind,
  skill_score real,
  bi_score real
)
```

Shape:

1. `my_cards`: viewer's discoverable cards of the opposite kind, with `ltree`.
2. `pairs`: candidate cards gated by `skill_pair_score >= p_min_skill`,
   onboarding, blocks, visibility, media. Keep **all** cards per user (no
   `distinct on`).
3. `card_bi`: for each pair, cosine between the viewer card's `query` vector
   and the candidate card's `passage` vector:
   ```sql
   (1 - extensions.cosine_distance(mq.embedding, cp.embedding))
   ```
   `left join` so a missing vector falls back to `skill_score`.
4. `context_bi`: existing user-level context vectors.
5. `bi_score = p_w_skills * coalesce(card_bi, skill_score) + p_w_context * context`.
6. Return top `p_limit` pairs ordered by `bi_score`, `skill_score`.

Cost control: the `pairs` CTE is the prefilter. Do not run cosine over the
whole `card_embeddings` table; join `card_embeddings` to `pairs` by `card_id`.

## 2.2 Rerank at card level

In `get-matches`:

- Direction A query = viewer's **source card** text
  (`build_card_passages` of the card that matched, plus context).
- Direction A documents = one text per **candidate card** (skill chain + note).
- Direction B query = the candidate card text; document = the viewer's source
  card text.
- Group by `(source_card_id, candidate_card_id)`; a person can appear multiple
  times.

Rebuild the `cardById` map from `match_cards` and use it for both rerank texts
and the response.

## 2.3 Cache v2

```sql
create table if not exists public.match_cache_v2 (
  user_id uuid not null,
  as_role public.embed_role not null,
  source_card_id uuid not null,
  candidate_card_id uuid not null,
  rank integer not null,
  bi_score real,
  rerank_score_a real,
  rerank_score_b real,
  reciprocal_score real not null,
  calibrated_score real not null,
  pipeline_mode text not null default 'full',
  display_name text,
  role text,
  skill_name text,
  skill_path text,
  skill_kind public.skill_kind,
  model_name text not null,
  config_version integer not null,
  refreshed_at timestamptz not null default now(),
  primary key (user_id, as_role, source_card_id, candidate_card_id)
);
```

- `cache_is_fresh_v2` adds `user_skills.updated_at`, `visibility`, and
  `skill_showcases.updated_at` to the invalidation checks.
- Prune: keep the newest `max_deck_size` per `(user_id, as_role)`; delete older
  rows on refresh.

## 2.4 Diversity pass

After ranking, before the cap:

```ts
const perUser = new Map<string, number>();
const perSkill = new Map<string, number>();
const deck = ranked.filter((s) => {
  const u = perUser.get(s.candidate_id) ?? 0;
  const k = perSkill.get(s.skill_id) ?? 0;
  if (u >= cfg.maxPerUser || k >= cfg.maxPerSkill) return false;
  perUser.set(s.candidate_id, u + 1);
  perSkill.set(s.skill_id, k + 1);
  return true;
}).slice(0, cfg.maxDeckSize);
```

## 2.5 Response contract

```jsonc
{
  "user_id": "â€¦",
  "card_id": "â€¦",             // the candidate card
  "source_card_id": "â€¦",      // my card that matched
  "skill_id": "â€¦",
  "skill_name": "Traditional Music",
  "skill_path": "music.traditional",
  "skill_kind": "teach",      // candidate side
  "compatibility": 0.82,
  "pipeline": "full"
}
```

`card_id` is the deck key when the client is ready.

---

# Phase 3 â€” client (5â€“7 days)

## 3.1 Model

`lib/screen/card/person_card.dart` â€” add to `Person`:

```dart
final String? cardId;
final String? sourceCardId;
final String? skillKind; // 'learn' | 'teach'
```

Keep `id` as the user id for profile navigation and connections. Card identity
is only for deck membership.

## 3.2 API

`fetchAndCacheDeck` builds a `Person` per result with `cardId`, `skillKind`,
and the matched `skillPath`. Enrichment already fetches the public profile; pick
the matching skill by path.

## 3.3 Deck keys

`home_page.dart`:

- `_seen` / `_hiddenIds` / replay compare `person.cardId ?? person.id`.
- `_sameDeck` compares card ids.
- `_mergeDecks` dedupes by **card id** now, not user id.
- The end-of-deck replay uses card ids.

Local `seen` sets from older builds contain user ids; they simply won't match
card ids, so a user may see a card once more. Acceptable; document it.

## 3.4 Card UI

- Badge above the skill: `Wants to learn` / `Teaches`, from `skillKind`.
- Note and showcases come from the matched card; if a showcase exists, it leads
  the media strip (already supported by `showcaseUrls`).
- â€œWhy this matchâ€ shows both sides: *you teach X Â· they want X* (or the
  reverse) using `sourceCardId` + `cardId`.

## 3.5 Requests and notifications

- `MatchApi.sendConnectionRequest` already accepts skill name/path; pass the
  card's skill (today it may pass a different one).
- `possible_match` notifications: dedupe per `(user, other_user)` per 24h, not
  per card. Include `skill_path` and `as_role` in the payload; the activity
  formatter already reads `as_role` and the skill.

---

# 4. Testing

## SQL

Add `supabase/tests/card_matching.sql` (run with `supabase test db` if pgTAP is
enabled, or as a plain DO block against the local DB):

1. Exact pair (`web.dev.web` â†” `web.dev.web`) â†’ score 1.0, included.
2. Parent/child pair â†’ 0.65/0.80, included above `min_skill_score`.
3. Siblings (`music.traditional` and `music.theory`) score 0.45; **excluded at
   the default 0.50 gate**. Lower `min_skill_score` to 0.45 only if the product
   wants adjacent skills in the deck.
4. Unrelated (`web.dev` â†” `music.traditional`) â†’ 0.0, excluded.
5. Teach card without a showcase â†’ excluded when `p_require_media`.
6. Blocked pair / existing connection â†’ excluded.
7. Empty result is allowed; no padding.

## Edge function

- Extract the pure helpers (`combineReciprocal`, diversity pass, response
  mapping) into `_shared/` and unit-test them with Deno:
  `deno test supabase/functions/_shared/*_test.ts`.
- Add one integration test against a seeded local Supabase stack for
  `matcher_mode=cards`.

## Flutter

- Widget test: a match with `skillPath` selects that skill, not the first.
- Widget test: two cards for the same person render separately (once the model
  supports it).
- Again run the full suite (`flutter test --no-pub`).

---

# 5. Rollout runbook

| Step | Action | Verify | Rollback |
|---|---|---|---|
| 1 | Apply Phase 0 migration | `select public.skill_pair_score('a.b'::ltree, 'a.b'::ltree)` = 1.0 | drop function |
| 2 | Deploy functions | `get-matches` returns `skill_path` | redeploy previous tag |
| 3 | Enable `matcher_mode=gated` for staff accounts | Reported pair excluded | set `matcher_mode=profile` |
| 4 | Phase 1 migration + backfill | `card_embeddings` â‰ˆ `user_skills` | drop table (no client impact) |
| 5 | Deploy Phase 2 behind `matcher_mode=cards` | deck shape, latency | config flip |
| 6 | Enable for 10% â†’ 50% â†’ 100% | funnel metrics | config flip |
| 7 | Phase 3 client release | card ids, requests | previous app build |
| 8 | Phase 4 cleanup (drop old columns/functions) after 2 weeks | â€” | restore from migration |

Config flip:

```sql
insert into public.pipeline_config (key, value)
values ('matcher_mode', '"cards"')
on conflict (key) do update set value = excluded.value;
```

`bump_config_revision()` fires on `pipeline_config` changes, so caches
invalidate automatically.

---

# 6. Metrics to watch

- **Zero-result rate** per deck (should rise slightly; never pad).
- **Unrelated-pair rate**: % of shown cards with `skill_score = 0` (must be 0).
- **Matched-skill mismatch**: % of cards whose displayed skill â‰  returned
  `skill_path` (must be 0).
- **Duplicate exposure**: cards per unique person per deck (`max_per_user`).
- **Request rate / acceptance / unmatch / report** per card and per skill.
- **p95 deck latency**, rerank calls per cold deck, embedding backlog.
- **Cache hit rate** and `match_cache_v2` row count per user.

---

# 7. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Empty decks for sparse skills | Medium | `min_skill_score` 0.5 + parent/child; Browse as escape hatch |
| Cache row explosion | High | PK includes cards; prune to deck size per refresh |
| Old client shows wrong skill | Low after Phase 0 | Phase 0 returns `skill_path`; client update |
| Notification spam per card | Medium | Dedupe per user pair per 24h |
| Backfill cost/time | Medium | Batches, resumable by hash, off-peak |
| Migration lock on `user_skills` | Low | Additive `add column`, no rewrite |
| Showcase-less teach cards vanish | Expected | Product copy + profile prompt to add a showcase |
| Third teaching skill after 3â†’2 cap | Medium | Keep hidden, don't delete; product decision |
| Card-level connection ambiguity | Medium | Keep connections user-level in v1 |

---

# 8. Checklist

- [ ] Phase 0 SQL + function deployed, staff flag on
- [ ] Reported pair verified excluded
- [ ] `skill_path` returned and rendered
- [ ] Phase 1 migration applied; `card_embeddings` backfilled
- [ ] `build_card_passages` hash stable across saves
- [ ] Phase 2 `match_cards` + rerank + cache v2
- [ ] Diversity pass (`max_per_user`, `max_per_skill`)
- [ ] Phase 3 client models, deck keys, request skill, badges
- [ ] SQL fixtures + Deno unit tests + widget tests
- [ ] Metrics dashboard + config rollback drilled
- [ ] Phase 4 cleanup scheduled


