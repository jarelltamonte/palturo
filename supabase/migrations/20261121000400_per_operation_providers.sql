-- Per-operation inference providers (hybrid: embed on one, rerank on another).
--
-- Each operation picks the provider that serves it. Both providers expose the
-- same Nemotron 3.5 embedding/rerank models, so vectors are interchangeable by
-- model name and only need regeneration when the embedding provider changes.
-- `inference_provider` is kept as the backwards-compatible embedding default.

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
on conflict (key) do nothing;

-- Seed both from the existing single-provider setting on first upgrade.
do $$
declare
  current_provider text;
begin
  select value #>> '{}' into current_provider
  from public.pipeline_config
  where key = 'inference_provider';

  if current_provider in ('nvidia', 'deepinfra') then
    update public.pipeline_config
    set value = to_jsonb(current_provider)
    where key in ('embed_provider', 'rerank_provider')
      and value = to_jsonb('nvidia'::text);
  end if;
end $$;
