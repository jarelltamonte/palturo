-- Inference provider switch (NVIDIA NIM or DeepInfra).
--
-- The provider owns the embedding and rerank endpoints/models (see
-- PROVIDER_PRESETS in supabase/functions/_shared/pipeline.ts). Switching it
-- changes the embedding model name, so stored vectors are ignored by model
-- name and regenerated lazily. The matching API key lives in the function
-- secrets as NIM_API_KEY or DEEPINFRA_API_KEY.

insert into public.pipeline_config (key, value, description)
values (
  'inference_provider',
  to_jsonb('nvidia'::text),
  'Embedding and rerank provider: nvidia (NIM) or deepinfra.'
)
on conflict (key) do nothing;
