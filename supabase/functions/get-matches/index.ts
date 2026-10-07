// PalTuro — get-matches Edge Function
// Full recommendation pipeline:
//   1. self-heal stale embeddings ( seekers + all opposite-role users, via NIM embed )
//   2. Stage 1 candidate retrieval: weighted multi-vector pgvector cosine (skills + context)
//   3. Stage 2: batched NIM rerank, BOTH directions
//   4. reciprocal score sqrt(a*b) on sigmoid-calibrated logits, rank, filter
//   5. write match_cache, return ranked list
// Fallback: if the reranker is unavailable → rank by bi-encoder score (pipeline_mode = basic_bi).

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  Admin, PipelineCfg, ensureFreshEmbeddings, getConfig, nimKey, nimEmbed, nimRerank, sigmoid,
} from "../_shared/pipeline.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "Missing bearer token" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: authData } = await userClient.auth.getUser();
    const user = authData?.user;
    if (!user) return json({ error: "Unauthorized" }, 401);

    let payload: { as_role?: string; refresh?: boolean };
    try {
      payload = await req.json();
    } catch {
      payload = {};
    }
    const targetRole = payload.as_role === "mentor" ? "mentor" : "learner"; // candidates I want
    const meRole = targetRole === "mentor" ? "learner" : "mentor";

    const cfg = await getConfig(admin);
    const key = await nimKey(admin);
    if (!key) return json({ error: "NIM_API_KEY not configured" }, 503);

    const started = Date.now();

    // ---------- CACHE-FIRST fast path ----------
    // If the cached ranking is still valid (same config; nothing changed since
    // refresh on either side), skip ALL NIM work and return the stored order.
    if (payload.refresh !== false) {
      const { data: fresh } = await admin.rpc("cache_is_fresh", {
        p_user: user.id,
        p_role: targetRole,
        p_revision: cfg.configRevision,
      });
      if (fresh === true) {
        const { data: cached } = await admin
          .from("match_cache")
          .select("candidate_id, rank, bi_score, reciprocal_score, calibrated_score, pipeline_mode")
          .eq("user_id", user.id)
          .eq("as_role", targetRole)
          .order("rank");
        const rows = (cached ?? []) as Array<Record<string, unknown>>;
        if (rows.length > 0) {
          const ids = rows.map((r) => r.candidate_id as string).concat(user.id);
          const { data: pRows } = await admin.rpc("profile_match_view", { p_users: ids });
          const profiles = (pRows ?? []) as Array<{ user_id: string; name: string; role: string }>;
          const nameOf = new Map(profiles.map((p) => [p.user_id, p]));
          const results = rows.map((r) => {
            const p = nameOf.get(r.candidate_id as string);
            return {
              user_id: r.candidate_id,
              rank: Number(r.rank),
              display_name: p?.name ?? "",
              role: p?.role ?? "both",
              compatibility: Number(r.calibrated_score ?? 0),
              pipeline: String(r.pipeline_mode ?? "full"),
              cached: true,
            };
          });
          return json({
            status: "ok",
            mode: "cached",
            healed: 0,
            config_version: cfg.configRevision,
            ms: Date.now() - started,
            results,
          });
        }
      }
    }

    // ---------- determine candidate pool ----------
    const allUsers = await admin.from("profiles").select("id").neq("id", user.id).limit(500);
    const candidateIds = (allUsers.data ?? []).map((r: any) => r.id) as string[];

    // ---------- 1. self-heal embeddings (me + candidates) ----------
    let healed = 0;
    if (payload.refresh !== false) {
      const res = await ensureFreshEmbeddings(admin, [user.id, ...candidateIds], cfg, key);
      healed = res.upserted;
    }

    // ---------- 2. Stage 1: weighted multi-vector retrieval (SQL) ----------
    const { data: cands, error: candErr } = await admin.rpc("match_candidates", {
      p_user: user.id,
      p_target: targetRole,
      p_limit: cfg.topK,
      p_w_skills: cfg.wSkills,
      p_w_context: cfg.wContext,
    });
    if (candErr) return json({ error: `candidate retrieval: ${candErr.message}` }, 500);
    const candidates = (cands ?? []) as Array<{ candidate_id: string; bi_score: number }>;

    if (candidates.length === 0) {
      await refreshCache(admin, user.id, targetRole, [], cfg, "full");
      return json({ status: "ok", mode: "full", results: [], healed, cachedRanking: true });
    }

    // ---------- fetch profile summaries + passages for rerank text ----------
    const ids = candidates.map((c) => c.candidate_id).concat(user.id);
    const { data: pRows, error: pErr } = await admin.rpc("profile_match_view", { p_users: ids });
    if (pErr) return json({ error: `profile view: ${pErr.message}` }, 500);
    const profiles = pRows as Array<{
      user_id: string; name: string; role: string; learner_text: string;
      mentor_text: string; learner_context: string; mentor_context: string;
    }>;
    const byId = new Map(profiles.map((p) => [p.user_id, p]));
    const me = byId.get(user.id)!;

    const myDoc = `${me.name}'s ${meRole === "learner" ? "LEARNING REQUEST" : "TEACHING OFFER"}\n${meRole === "learner" ? me.learner_text : me.mentor_text}\n${meRole === "learner" ? me.learner_context : me.mentor_context}`;

    // ---------- 3. NIM rerank: direction A (batched) and B (parallel per candidate) ----------
    const docs = candidates.map((c) => {
      const p = byId.get(c.candidate_id)!;
      return `${p.name}'s ${targetRole === "mentor" ? "TEACHING OFFER" : "LEARNING REQUEST"}\n${
        targetRole === "mentor" ? p.mentor_text : p.learner_text
      }\n${targetRole === "mentor" ? p.mentor_context : p.learner_context}`;
    });

    let mode = "full";
    let rerankA: Array<{ index: number; logit: number }>;
    let rerankB: number[] = [];
    try {
      rerankA = await nimRerank(key, cfg, myDoc, docs);

      // direction B: does the candidate also want mtahc with me? (their request vs my offer)
      const bQueries = candidates.map((c) => {
        const p = byId.get(c.candidate_id)!;
        return `${p.name}'s ${targetRole === "mentor" ? "LEARNING REQUEST" : "TEACHING OFFER"}\n${
          targetRole === "mentor" ? p.learner_text : p.mentor_text
        }\n${targetRole === "mentor" ? p.learner_context : p.mentor_context}`;
      });
      const myOfferDoc =
        `${me.name}'s ${targetRole === "mentor" ? "TEACHING OFFER" : "LEARNING REQUEST"}\n${
          targetRole === "mentor" ? me.mentor_text : me.learner_text
        }\n${targetRole === "mentor" ? me.mentor_context : me.learner_context}`;
      const bResults = await Promise.all(
        bQueries.map((q) => nimRerank(key, cfg, q, [myOfferDoc]).then((r) => r[0]?.logit ?? null)
          .catch(() => null)),
      );
      rerankB = bResults as number[];
    } catch (e) {
      // graceful fallback to basic matching (bi-encoder ranking only)
      mode = "basic_bi";
      rerankA = [];
    }

    // ---------- 4. reciprocal + calibration ----------
    const scored = candidates.map((c, i) => {
      const la = mode === "full" ? rerankA[i]?.logit ?? null : null;
      const lb = mode === "full" ? rerankB[i] ?? null : null;
      const pa = la === null ? null : sigmoid(la);
      const pb = lb === null ? null : sigmoid(lb);
      const biScore = c.bi_score;
      let reciprocal: number;
      let calibrated: number;
      if (pa !== null && pb !== null) {
        reciprocal = Math.sqrt(pa * pb);
        calibrated = cfg.calibration === "minmax" ? reciprocal : reciprocal; // sigmoid already calibrated
      } else {
        reciprocal = Math.max(biScore, 0);
        calibrated = reciprocal;
      }
      return {
        candidate_id: c.candidate_id,
        bi_score: biScore,
        rerank_score_a: pa,
        rerank_score_b: pb,
        reciprocal_score: reciprocal,
        calibrated_score: calibrated,
      };
    });

    scored.sort((a, b) => b.calibrated_score - a.calibrated_score);
    const ranked = scored.map((s, i) => ({ ...s, rank: i + 1 }));

    await refreshCache(admin, user.id, targetRole, ranked, cfg, mode);

    const results = ranked.map((s) => {
      const p = byId.get(s.candidate_id)!;
      return {
        user_id: s.candidate_id,
        rank: s.rank,
        display_name: p.name,
        role: p.role,
        compatibility: s.calibrated_score,
        bi_score: s.bi_score,
        pipeline: mode,
      };
    });

    return json({
      status: "ok",
      mode,
      healed,
      config_version: cfg.configRevision,
      ms: Date.now() - started,
      results,
    });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});

async function refreshCache(
  admin: Admin,
  userId: string,
  asRole: string,
  ranked: Array<{
    candidate_id: string; rank: number; bi_score: number;
    rerank_score_a: number | null; rerank_score_b: number | null;
    reciprocal_score: number; calibrated_score: number; mode?: string;
  }>,
  cfg: PipelineCfg,
  mode: string,
) {
  await admin.from("match_cache").delete().eq("user_id", userId).eq("as_role", asRole);
  if (ranked.length === 0) return;
  const payload = ranked.map((s) => ({
    user_id: userId,
    as_role: asRole,
    candidate_id: s.candidate_id,
    rank: s.rank,
    bi_score: s.bi_score,
    rerank_score_a: s.rerank_score_a,
    rerank_score_b: s.rerank_score_b,
    reciprocal_score: s.reciprocal_score,
    calibrated_score: s.calibrated_score,
    pipeline_mode: mode,
    model_name: mode === "full" ? cfg.rerankModel : cfg.embeddingModel,
    config_version: cfg.configRevision,
  }));
  await admin.from("match_cache").insert(payload);
}
