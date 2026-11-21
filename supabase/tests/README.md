# Local matching tests

These fixtures exercise the card-level matcher against a real local Supabase
stack. They are not part of CI.

## Bootstrap

The repo's migrations are incremental on top of `supabase/schema.sql`. Follow
`supabase/README.md`:

1. Start Docker and the stack with the migrations temporarily moved aside:
   ```powershell
   npx supabase@3.1.0 start
   ```
2. Restore `schema.sql`, then:
   ```powershell
   docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/schema.sql
   docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/seed.sql
   npx supabase@3.1.0 migration repair --status applied <ids through 20261023001700>
   npx supabase@3.1.0 migration up
   ```
3. Create the 20 accounts and their data:
   ```powershell
   powershell -ExecutionPolicy Bypass -File supabase/tests/seed_local_accounts.ps1
   docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/seed_local_accounts.sql
   docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/seed_local_embeddings.sql
   ```
   Every account uses password `TestPass123!`.

## Fixtures

- 18 both-role accounts and 2 learner-only accounts.
- 39 skill cards: 18 teach, 21 learn, 1 paused (Marisol's Woodworking).
- 18 showcases (one video), all notes approved.
- Reciprocal pairs: Marisol/Lourdes (WebDev/Cooking), Emilio/Andres
  (Calligraphy/Traditional Music), Bianca/Marco, Carmela/Nathaniel,
  Joaquin/Camille, Elias/Teresa, Miguel/Patricia.
- The reported failure: Diego learns Traditional Music, Marisol teaches Web
  Development only. Diego must never appear in Marisol's learner deck.

## Run

```powershell
# pure SQL assertions
docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/card_pair_score.sql
docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/card_matching_fixtures.sql
docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/card_matching_matrix.sql
docker exec -i supabase_db_palturo psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/card_serving_audit.sql

# exhaustive HTTP audit: 20 accounts x 2 directions, fresh and cached
powershell -ExecutionPolicy Bypass -File supabase/tests/audit_local_serving.ps1

# real edge function
npx supabase@3.1.0 functions serve get-matches --env-file <env with dummy provider keys>
# then POST /functions/v1/get-matches with a user JWT

# real Flutter client (opt-in)
$env:PALTURO_LOCAL_TEST = "1"
flutter test --no-pub test/local_matching_integration_test.dart
```

The function needs `NIM_API_KEY`/`DEEPINFRA_API_KEY` present. Without valid
keys the reranker falls back to `basic_bi`; the card gate and response shape are
still exercised.

`matcher_mode` values:

- `profile` — legacy whole-profile matcher (shows unrelated pairs; the original
  bug).
- `gated` — profile rerank + card retrieval gate.
- `cards` — card-pair retrieval, scoring, diversity, and cache v2.

Switch locally with:

```sql
update public.pipeline_config
set value = '"cards"'::jsonb
where key = 'matcher_mode';
```
