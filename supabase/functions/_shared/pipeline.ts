// PalTuro — shared NIM client + pipeline helpers (used by generate-embeddings & get-matches)

import { createClient } from "jsr:@supabase/supabase-js@2";

export type Admin = ReturnType<typeof createClient>;

export const sigmoid = (x: number) => 1 / (1 + Math.exp(-x));

export const unstr = (v: unknown, dflt: string) =>
  typeof v === "string" ? v.replace(/"/g, "").replace(/\\n/g, "\n") : dflt;
export const num = (v: unknown, dflt: number) =>
  Number.isFinite(Number(v)) ? Number(v) : dflt;

export interface PipelineCfg {
  embeddingModel: string;
  rerankModel: string;
  embeddingDim: number;
  embeddingApi: string;
  rerankApi: string;
  wSkills: number;
  wContext: number;
  topK: number;
  configRevision: number;
}

export async function getConfig(admin: Admin): Promise<PipelineCfg> {
  const { data: rows } = await admin.from("pipeline_config").select("key,value");
  const cfg: Record<string, any> = {};
  for (const r of rows ?? []) cfg[r.key] = r.value;
  const weights = cfg.embedding_weights ?? {};
  return {
    embeddingModel: unstr(cfg.embedding_model, "nvidia/nemotron-3.5-embed-1b"),
    rerankModel: unstr(cfg.rerank_model, "nvidia/nemotron-3.5-rerank-8b"),
    embeddingDim: num(cfg.embedding_dim, 1024),
    embeddingApi: unstr(cfg.embedding_api, "https://integrate.api.nvidia.com/v1/embeddings"),
    rerankApi: unstr(
      cfg.rerank_api,
      "https://ai.api.nvidia.com/v1/retrieval/nvidia/nemotron-3.5-rerank-8b/reranking",
    ),
    wSkills: Number(weights.skills ?? 0.7),
    wContext: Number(weights.context ?? 0.3),
    topK: num(cfg.candidate_pool_k, 50),
    configRevision: num(cfg.__revision, 0),
  };
}

export async function nimKey(admin: Admin): Promise<string | null> {
  let key = Deno.env.get("NIM_API_KEY");
  if (!key) {
    const { data } = await admin
      .from("integration_secrets")
      .select("value")
      .eq("name", "NIM_API_KEY")
      .maybeSingle();
    key = (data as any)?.value ?? null;
  }
  return key;
}

/** Embed texts with the NIM embedding model. inputType: 'query' | 'passage'. */
export async function nimEmbed(
  key: string,
  cfg: PipelineCfg,
  texts: string[],
  inputType: "query" | "passage",
  timeoutMs = 30000,
): Promise<number[][]> {
  const res = await fetch(cfg.embeddingApi, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      input: texts,
      model: cfg.embeddingModel,
      input_type: inputType,
      dimensions: cfg.embeddingDim,
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) {
    throw new Error(`NIM embed failed (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  // response: { data: [{ embedding: number[] }, ...] }
  return (data.data ?? []).map((d: any) => d.embedding as number[]);
}

/** Rerank passages against a query. Returns [{index, logit}]. */
export async function nimRerank(
  key: string,
  cfg: PipelineCfg,
  queryText: string,
  passageTexts: string[],
  timeoutMs = 30000,
): Promise<Array<{ index: number; logit: number }>> {
  const res = await fetch(cfg.rerankApi, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({
      model: cfg.rerankModel,
      // Hosted rerankers each expose their own /v1/retrieval/<model>/reranking
      // endpoint, and the model field must name that same model.
      query: { text: queryText },
      passages: passageTexts.map((t) => ({ text: t })),
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) {
    throw new Error(`NIM rerank failed (${res.status}): ${await res.text()}`);
  }
  return (await res.json()).rankings ?? [];
}

const vecLiteral = (e: number[]) => `[${e.join(",")}]`;

/**
 * Ensure profile_embeddings rows (both input types) are current for the given users.
 * Reads build_profile_passages() (SQL) and diffs against stored source_hash.
 */
export async function ensureFreshEmbeddings(
  admin: Admin,
  userIds: string[],
  cfg: PipelineCfg,
  key: string,
  timeoutMs = 30000,
): Promise<{ upserted: number; costEmbeddings: number }> {
  if (userIds.length === 0) return { upserted: 0, costEmbeddings: 0 };

  // passages via bulk SQL function
  const { data, error } = await admin.rpc("build_passages_bulk", { p_users: userIds });
  if (error) throw new Error(`passages: ${error.message}`);
  const rows = (data ?? []) as Array<{
    user_id: string;
    role: string;
    field_group: string;
    source_text: string;
    source_hash: string;
  }>;
  if (rows.length === 0) return { upserted: 0, costEmbeddings: 0 };

  // existing stored hashes (scoped to the users being healed). Vectors from a
  // different embedding model are treated as missing: comparing vectors across
  // models produces meaningless scores, and providers retire models.
  const { data: existing, error: existingErr } = await admin
    .from("profile_embeddings")
    .select("user_id,role,field_group,input_type,source_hash,model_name")
    .in("user_id", userIds);
  if (existingErr) throw new Error(`embeddings: ${existingErr.message}`);
  const have = new Set(
    (existing ?? [])
      .filter((r) => r.model_name === cfg.embeddingModel)
      .map((r) => `${r.user_id}|${r.role}|${r.field_group}|${r.input_type}:${r.source_hash}`),
  );

  const toUpsert = rows.filter((r) => {
    const kPass = `${r.user_id}|${r.role}|${r.field_group}|passage:${r.source_hash}`;
    const kQuery = `${r.user_id}|${r.role}|${r.field_group}|query:${r.source_hash}`;
    return !have.has(kPass) || !have.has(kQuery);
  });
  if (toUpsert.length === 0) return { upserted: 0, costEmbeddings: 0 };

  // Each input type is refreshed independently. Delete only the keys in this
  // batch: deleting every touched pair would remove a still-valid query vector
  // when only the passage changed (and vice versa).
  let cost = 0;
  for (const inputType of ["passage", "query"] as const) {
    const batch = toUpsert.filter((r) => {
      const k = `${r.user_id}|${r.role}|${r.field_group}|${inputType}:${r.source_hash}`;
      return !have.has(k);
    });
    if (batch.length === 0) continue;

    const vectors = await nimEmbed(
      key,
      cfg,
      batch.map((r) => r.source_text),
      inputType,
      timeoutMs,
    );
    if (vectors.length !== batch.length) {
      throw new Error(
        `embedding count mismatch: expected ${batch.length}, got ${vectors.length}`,
      );
    }
    const payload = batch.map((r, i) => ({
      user_id: r.user_id,
      role: r.role,
      field_group: r.field_group,
      input_type: inputType,
      source_text: r.source_text,
      source_hash: r.source_hash,
      model_name: cfg.embeddingModel,
      embedding: vecLiteral(vectors[i]),
    }));

    const batchKeys = new Set(
      batch.map((r) => `${r.user_id}|${r.role}|${r.field_group}`),
    );
    for (const key of batchKeys) {
      const [user_id, role, field_group] = key.split("|");
      const { error: delErr } = await admin
        .from("profile_embeddings")
        .delete()
        .eq("user_id", user_id)
        .eq("role", role)
        .eq("field_group", field_group)
        .eq("input_type", inputType);
      if (delErr) throw new Error(`embedding delete: ${delErr.message}`);
    }
    const { error: insErr } = await admin.from("profile_embeddings").insert(payload);
    if (insErr) throw new Error(`embedding upsert: ${insErr.message}`);
    cost += vectors.length * 0.00002; // rough estimate for instrumentation honesty
  }

  // Healed vectors change candidate rankings. Invalidate cached decks that
  // contain this user (and the user's own deck) so stale caches cannot keep
  // them invisible until the next TTL.
  const candidateCache = await admin
    .from("match_cache")
    .delete()
    .in("candidate_id", userIds);
  if (candidateCache.error) {
    console.error(`[embeddings] cache invalidation (candidate): ${candidateCache.error.message}`);
  }
  const userCache = await admin
    .from("match_cache")
    .delete()
    .in("user_id", userIds);
  if (userCache.error) {
    console.error(`[embeddings] cache invalidation (user): ${userCache.error.message}`);
  }

  return { upserted: toUpsert.length, costEmbeddings: cost };
}
