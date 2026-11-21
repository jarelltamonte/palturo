-- Per-operation inference providers (hybrid: embed on one, rerank on another).
--
-- Each operation picks the provider that serves it. Both providers expose the
-- Nemotron 3.5 family, so vectors only need regeneration when the embedding
-- provider/model changes. `inference_provider` is kept as the backwards-
-- compatible embedding default.

-- Seed only the rows this migration inserted, so re-running it on a deliberate
-- hybrid (DeepInfra embed + NIM rerank) never rewrites the rerank choice.
do $$
declare
  inserted_keys text[];
  current_provider text;
  embed_provider text;
  rerank_provider text;
begin
  with ins as (
    insert into public.pipeline_config (key, value, description)
    values
      (
        'embed_provider',
        to_jsonb('nvidia'::text),
        'Embedding provider: nvidia (NIM) or deepinfra.'
      ),
      (
        'rerank_provider',
        to_jsonb('nvidia'::text),
        'Rerank provider: nvidia (NIM) or deepinfra.'
      )
    on conflict (key) do nothing
    returning key
  )
  select coalesce(array_agg(key), '{}') into inserted_keys from ins;

  select value #>> '{}' into current_provider
  from public.pipeline_config
  where key = 'inference_provider';
  if current_provider not in ('nvidia', 'deepinfra') then
    current_provider := 'nvidia';
  end if;

  if 'embed_provider' = any(inserted_keys) then
    update public.pipeline_config
    set value = to_jsonb(current_provider)
    where key = 'embed_provider';
  end if;
  if 'rerank_provider' = any(inserted_keys) then
    update public.pipeline_config
    set value = to_jsonb(current_provider)
    where key = 'rerank_provider';
  end if;

  select value #>> '{}' into embed_provider
  from public.pipeline_config where key = 'embed_provider';
  select value #>> '{}' into rerank_provider
  from public.pipeline_config where key = 'rerank_provider';

  -- The SQL retrieval functions read these model names. Keep them in lockstep
  -- with the selected presets so a legacy config missing the key cannot fall
  -- back to the other provider's vector space.
  insert into public.pipeline_config (key, value, description)
  values (
    'embedding_model',
    to_jsonb(case embed_provider
      when 'deepinfra' then 'nvidia/Nemotron-3.5-Embed-8B-BF16'
      else 'nvidia/nemotron-3.5-embed-1b'
    end),
    'Embedding model name read by match_candidates; owned by embed_provider.'
  )
  on conflict (key) do update set value = excluded.value;

  insert into public.pipeline_config (key, value, description)
  values (
    'rerank_model',
    to_jsonb(case rerank_provider
      when 'deepinfra' then 'nvidia/Nemotron-3.5-Rerank-8B-BF16'
      else 'nvidia/nemotron-3.5-rerank-8b'
    end),
    'Rerank model name; owned by rerank_provider.'
  )
  on conflict (key) do update set value = excluded.value;

  insert into public.pipeline_config (key, value, description)
  values (
    'embedding_api',
    to_jsonb(case embed_provider
      when 'deepinfra' then 'https://api.deepinfra.com/v1/openai/embeddings'
      else 'https://integrate.api.nvidia.com/v1/embeddings'
    end),
    'Embedding endpoint; owned by embed_provider.'
  )
  on conflict (key) do update set value = excluded.value;

  insert into public.pipeline_config (key, value, description)
  values (
    'rerank_api',
    to_jsonb(case rerank_provider
      when 'deepinfra' then 'https://api.deepinfra.com/v1/inference/nvidia/Nemotron-3.5-Rerank-8B-BF16'
      else 'https://ai.api.nvidia.com/v1/retrieval/nvidia/nemotron-3.5-rerank-8b/reranking'
    end),
    'Rerank endpoint; owned by rerank_provider.'
  )
  on conflict (key) do update set value = excluded.value;
end $$;
