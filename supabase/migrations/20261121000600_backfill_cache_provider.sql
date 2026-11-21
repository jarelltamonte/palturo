-- Backfill the provider on caches created before rerank fallback shipped.
-- Kept in its own migration so the ACCESS EXCLUSIVE lock from adding the
-- column in 20261121000500 is released before this table-wide update runs.

update public.match_cache
set rerank_provider = 'none'
where rerank_provider is null
  and pipeline_mode is distinct from 'full';
