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
  wBio: number;
  topK: number;
  calibration: string;
  configRevision: number;
}

export async function getConfig(admin: Admin): Promise<PipelineCfg> {
  const { data: rows } = await admin.from("pipeline_config").select("key,value");
  const cfg: Record<string, any> = {};
  for (const r of rows ?? []) cfg[r.key] = r.value;
  const weights = cfg.embedding_weights ?? {};
  return {
    embeddingModel: unstr(cfg.embedding_model, "nvidia/llama-nemotron-embed-vl-1b-v2"),
    rerankModel: unstr(cfg.rerank_model, "nvidia/llama-nemotron-rerank-vl-1b-v2"),
    embeddingDim: num(cfg.embedding_dim, 1024),
    embeddingApi: unstr(cfg.embedding_api, "https://integrate.api.nvidia.com/v1/embeddings"),
    rerankApi: unstr(
      cfg.rerank_api,
      "https://ai.api.nvidia.com/v1/retrieval/nvidia/llama-nemotron-rerank-vl-1b-v2/reranking",
    ),
    wSkills: Number(weights.skills ?? 0.7),
    wContext: Number(weights.context ?? 0.3),
    wBio: Number(weights.bio ?? 0.0),
    topK: num(cfg.candidate_pool_k, 50),
    calibration: unstr(cfg.calibration, "sigmoid"),
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
): Promise<Array<{ index: number; logit: number }>> {
  const res = await fetch(cfg.rerankApi, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, Accept: "application/json", "Content-Type": "application/json" },
    body: JSON.stringify({
      model: cfg.rerankModel,
      // NOTE: model param accepted for tracking; VL reranker input: query + passages
      query: { text: queryText },
      passages: passageTexts.map((t) => ({ text: t })),
    }),
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

  // existing stored hashes
  const { data: existing } = await admin
    .from("profile_embeddings")
    .select("user_id,role,field_group,input_type,source_hash");
  const have = new Set(
    (existing ?? []).map((r) => `${r.user_id}|${r.role}|${r.field_group}|${r.input_type}:${r.source_hash}`),
  );

  const toUpsert = rows.filter((r) => {
    const kPass = `${r.user_id}|${r.role}|${r.field_group}|passage:${r.source_hash}`;
    const kQuery = `${r.user_id}|${r.role}|${r.field_group}|query:${r.source_hash}`;
    return !have.has(kPass) || !have.has(kQuery);
  });
  if (toUpsert.length === 0) return { upserted: 0, costEmbeddings: 0 };

  // delete stale rows for touched (user,role,group) pairs before insert
  const touched = new Set(toUpsert.map((r) => `${r.user_id}|${r.role}|${r.field_group}`));
  const toDelete: Array<{ user_id: string; role: string; field_group: string }> = [...touched].map((s) => {
    const [user_id, role, field_group] = s.split("|");
    return { user_id, role, field_group };
  });

  let cost = 0;
  for (const inputType of ["passage", "query"] as const) {
    const batch = toUpsert.filter((r) => {
      const k = `${r.user_id}|${r.role}|${r.field_group}|${inputType}:${r.source_hash}`;
      return !have.has(k);
    });
    if (batch.length === 0) continue;

    const vectors = await nimEmbed(key, cfg, batch.map((r) => r.source_text), inputType);
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

    // delete old rows for these keys (per input_type!) then insert
    for (const d of toDelete) {
      await admin
        .from("profile_embeddings")
        .delete()
        .eq("user_id", d.user_id)
        .eq("role", d.role)
        .eq("field_group", d.field_group)
        .eq("input_type", inputType);
    }
    const { error: insErr } = await admin.from("profile_embeddings").insert(payload);
    if (insErr) throw new Error(`embedding upsert: ${insErr.message}`);
    cost += vectors.length * 0.00002; // rough estimate for instrumentation honesty
  }

  return { upserted: toUpsert.length, costEmbeddings: cost };
}
