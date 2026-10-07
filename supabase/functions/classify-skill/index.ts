// PalTuro — classify-skill Edge Function (v2: two-stage moderation)
//
// Stage 1 — SKILL ingestion decision: judged on skill_name ONLY (note never included).
//           attach_existing | create_new | reject_invalid | reject_unsafe
// Stage 2 — NOTE moderation (separate Jev call, only when a note exists):
//           relevance + safety gates decide whether the note is stored.
//
// Everything configurable lives in pipeline_config (moderation_guidelines,
// decision_model, thresholds). Every verdict is logged to skill_moderation_log.
// Secrets: OPENROUTER_API_KEY (via `supabase secrets set`).
// Auto-injected: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "jsr:@supabase/supabase-js@2";

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

const normalize = (s: string) =>
  (s ?? "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ")
    .replace(/[^a-z0-9_ ]/g, "")
    .replace(/ +/g, "_")
    .replace(/^_+|_+$/g, "");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    // ---------- auth ----------
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ error: "Missing bearer token" }, 401);
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: authData, error: authErr } = await userClient.auth.getUser();
    const user = authData?.user;
    if (authErr || !user) return json({ error: "Unauthorized" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ---------- input ----------
    let payload: { name?: string; note?: string; kind?: string };
    try {
      payload = await req.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }
    const name = (payload.name ?? "").toString().trim();
    const note = (payload.note ?? "").toString().trim().slice(0, 500);
    const kind = payload.kind === "teach" ? "teach" : "learn";
    if (name.length < 2 || name.length > 80) {
      return json({ error: "Skill name must be 2-80 characters" }, 400);
    }

    // ---------- config ----------
    const { data: configRows } = await admin.from("pipeline_config").select("key,value");
    const cfg: Record<string, any> = {};
    for (const row of configRows ?? []) cfg[row.key] = row.value;
    const revision = Number(cfg["__revision"] ?? 0);
    const unstr = (v: unknown, dflt: string) =>
      typeof v === "string" ? v.replace(/"/g, "") : dflt;
    const num = (v: unknown, dflt: number) => Number.isFinite(Number(v)) ? Number(v) : dflt;

    const model = unstr(cfg.decision_model, "typesafe/jev-1.13");
    const confThreshold = num(cfg.decision_confidence_threshold, 0.8);
    const skillFloor = num(cfg.decision_min_skill, 0.6);
    const safetyFloor = num(cfg.decision_min_safety, 0.6);
    const noteRelevanceFloor = num(cfg.note_min_relevance, 0.6);
    const noteSafetyFloor = num(cfg.note_min_safety, 0.6);
    const promptVersion = unstr(cfg.decision_prompt_version, "v1");
    const guidelines =
      typeof cfg.moderation_guidelines === "string"
        ? cfg.moderation_guidelines.replace(/^"|"$/g, "")
        : DEFAULT_GUIDELINES;

    // ---------- taxonomy ----------
    const { data: nodes, error: nodesErr } = await admin
      .from("skill_nodes")
      .select("id,name,path,depth,is_leaf,is_visible,status")
      .order("path");
    if (nodesErr || !nodes) return json({ error: "Failed to load taxonomy" }, 500);

    const roots = nodes.filter((n) => n.depth === 1);
    const groups = nodes.filter((n) => n.depth === 2);
    const leaves = nodes.filter((n) => n.is_leaf && n.status === "approved");

    // ---------- Stage 1 fast path: exact match ----------
    const normalized = normalize(name);
    const exact = leaves.find((n) => normalize(n.name) === normalized);
    let skillDecision: {
      status: "attached" | "pending" | "queued" | "rejected" | "error";
      node: Record<string, unknown> | null;
      action: string;
      confidence: number | null;
      placementId?: string | null;
      stage1Answers?: unknown;
    };

    if (exact) {
      const placed = await placeSkill(admin, user.id, exact.id, kind, null);
      if (placed.error) return json({ error: placed.error, status: "error" }, 409);
      skillDecision = { status: "attached", node: pick(exact), action: "attach_existing", confidence: 1.0, placementId: placed.id };
    } else {
      // ---------- Stage 1: Jev call — skill ONLY (note excluded by design) ----------
      const state1 =
        `== SKILL RELEVANCY & SAFETY GUIDELINES ==\n${guidelines}\n\n` +
        `== TAXONOMY ==\n` +
        nodes.filter((n) => n.is_visible).map((n) => `${"  ".repeat(n.depth - 1)}- ${n.name}${n.is_leaf ? " (skill)" : ""}`).join("\n") +
        `\n\n== SUBMISSION ==\nSkill name: "${name}"\nIntent: the user wants to ${kind === "teach" ? "TEACH" : "LEARN"} this skill.\n\n` +
        `Decide how to handle this submission. If a taxonomy skill already covers its meaning, prefer attach_existing and pick the fitting group. ` +
        `If it is a genuinely new teachable/learnable skill, choose create_new and pick the most specific visible group. ` +
        `Judge ONLY the skill name. There is no user note in this evaluation by design.`;

      const questions1 = {
        action: {
          type: "choice",
          instructions: "How should this submission be handled?",
          criteria: {
            attach_existing: "An approved taxonomy skill already covers this submission's meaning",
            create_new: "A genuinely new, teachable/learnable skill that fits the taxonomy",
            reject_invalid: "Not a teachable/learnable skill (one-off action, event, product, brand, person, gibberish)",
            reject_unsafe: "Violates the safety guidelines (harmful, illegal, inappropriate content)",
          },
        },
        root_category: {
          type: "choice",
          instructions: "Which top-level domain fits this skill best?",
          criteria: Object.fromEntries(roots.map((r) => [normalize(r.name), r.name])),
        },
        subgroup: {
          type: "choice",
          instructions: "Which visible group within the taxonomy fits this skill best?",
          criteria: Object.fromEntries(groups.map((g) => [normalize(g.name), g.name])),
        },
        is_skill: { type: "noul", instructions: "Is this a plausible teachable/learnable practical or cultural skill?" },
        is_safe: { type: "noul", instructions: "Is this submission free of unsafe, illegal, or inappropriate content per the safety guidelines?" },
      };

      const orRes = await jevCall(model, state1, questions1, admin);

      if (!orRes.ok) {
        await log(admin, { user: user.id, name, note: null, answers: { http_error: orRes.status }, action: "queued", confidence: null, model, promptVersion, revision, stage: "stage1_skill" });
        return json({ status: "queued", reason: `Decision service unavailable (${orRes.status})` });
      }

      const v1 = await orRes.json();
      const a1 = v1.answers ?? {};
      const isSkill = Number(a1.is_skill?.noul ?? 0);
      const isSafe = Number(a1.is_safe?.noul ?? 0);
      const actionChoice = (a1.action?.choice as string | undefined) ?? "";
      const actionConf = (a1.action?.confidence as number | undefined) ?? null;
      const costTotal = Number(v1?.usage?.cost ?? 0);

      if (isSkill < skillFloor || isSafe < safetyFloor ||
          actionChoice === "reject_invalid" || actionChoice === "reject_unsafe") {
        const reason =
          isSafe < safetyFloor || actionChoice === "reject_unsafe"
            ? "safety"
            : "invalid_skill";
        await log(admin, { user: user.id, name, note: null, answers: a1, action: actionChoice || "reject_invalid", confidence: actionConf, model, promptVersion, revision, cost: costTotal, stage: "stage1_skill" });
        return json({ status: "rejected", reason, confidence: actionConf });
      }

      const groupNode = groups.find((g) => normalize(g.name) === a1.subgroup?.choice);
      const rootChoice = a1.root_category?.choice as string | undefined;

      if (actionChoice === "attach_existing") {
        // token-overlap match among approved leaves under the suggested subtree
        const subtree = groupNode
          ? leaves.filter((n) => String(n.path).startsWith(`${groupNode.path}.`))
          : leaves;
        const toks = new Set(normalized.split("_").filter((t) => t.length > 2));
        const best = subtree
          .map((n) => ({
            n,
            overlap: normalize(n.name).split("_").filter((t) => toks.has(t)).length,
          }))
          .sort((a, b) => b.overlap - a.overlap)[0];
        if (best && best.overlap > 0 && (actionConf ?? 0) >= confThreshold) {
          const placed = await placeSkill(admin, user.id, best.n.id, kind, null);
          if (placed.error) return json({ error: placed.error, status: "error" }, 409);
          skillDecision = { status: "attached", node: pick(best.n), action: "attach_existing", confidence: actionConf, placementId: placed.id };
        } else {
          skillDecision = { status: "queued", node: null, action: "queued", confidence: actionConf, stage1Answers: a1 };
        }
      } else if (actionChoice === "create_new") {
        const parent = groupNode ?? roots.find((r) => r.name === rootChoice);
        if (!parent) {
          skillDecision = { status: "queued", node: null, action: "queued", confidence: actionConf, stage1Answers: a1 };
        } else {
          const { data: newNode, error: nodeErr } = await admin
            .from("skill_nodes")
            .insert({ name, parent_id: parent.id, is_leaf: true, origin: "user_submitted", status: "pending", submitted_by: user.id })
            .select("id,name,path,status")
            .single();
          if (nodeErr) return json({ error: nodeErr.message, status: "error" }, 500);
          const placed = await placeSkill(admin, user.id, (newNode as any).id, kind, null);
          if (placed.error) return json({ error: placed.error, status: "error" }, 409);
          skillDecision = { status: "pending", node: newNode as any, action: "create_new", confidence: actionConf, placementId: placed.id };
        }
      } else {
        skillDecision = { status: "queued", node: null, action: "queued", confidence: actionConf, stage1Answers: a1 };
      }

      await log(admin, { user: user.id, name, note: null, answers: a1, action: skillDecision.action, confidence: actionConf, model, promptVersion, revision, cost: costTotal, stage: "stage1_skill" });
    }

    // ---------- Stage 2: note moderation (separate call; note never influences Stage 1) ----------
    let noteStored = false;
    let noteVerdict: Record<string, unknown> | null = null;

    if (note.length > 0) {
      const state2 =
        `== NOTE CONTEXT RULES ==\n` +
        `A note on a skill placement should describe the user's goals, teaching approach, background, schedule constraints, or expectations for THAT skill.\n` +
        `A note is NOT relevant if it discusses an unrelated activity, event, or aspiration (e.g. joining a fun run when the skill is cooking).\n\n` +
        `== SKILL ==\n"${skillDecision.node?.["name"] ?? name}"\n\n== USER NOTE ==\n"${note}"`;

      const questions2 = {
        note_relevant: {
          type: "noul",
          instructions: "Is this note relevant to the skill above (goals, approach, constraints, expectations for that skill)?",
        },
        note_safe: {
          type: "noul",
          instructions: "Is this note free of unsafe, illegal, or inappropriate content?",
        },
      };

      const orRes2 = await jevCall(model, state2, questions2, admin);

      if (orRes2.ok) {
        const v2 = await orRes2.json();
        const a2 = v2.answers ?? {};
        noteVerdict = a2;
        const relevant = Number(a2.note_relevant?.noul ?? 0);
        const safe = Number(a2.note_safe?.noul ?? 0);
        noteStored = relevant >= noteRelevanceFloor && safe >= noteSafetyFloor;
        await log(admin, {
          user: user.id, name, note,
          answers: a2,
          action: noteStored ? "note_accepted" : "note_rejected",
          confidence: null, model, promptVersion, revision,
          cost: Number(v2?.usage?.cost ?? 0),
          stage: "stage2_note",
        });
      } else {
        // service hiccup: keep the note out (conservative), log the failure
        await log(admin, { user: user.id, name, note, answers: { http_error: orRes2.status }, action: "note_queued", confidence: null, model, promptVersion, revision, stage: "stage2_note" });
      }
    }

    if (noteStored && skillDecision.placementId) {
      await admin.from("user_skills").update({ note }).eq("id", skillDecision.placementId);
    }

    return json({
      status: skillDecision.status,
      node: skillDecision.node,
      confidence: skillDecision.confidence,
      note_stored: noteStored,
      note_verdict: noteVerdict,
    });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});

// ---------------- helpers ----------------

const DEFAULT_GUIDELINES =
  "SKILL RELEVANCY GUIDELINES:\n" +
  "A skill is a competence a person can teach to or learn from another person through practice - practical, creative, cultural, or everyday (e.g., cooking a dish, weaving a textile, performing a folk dance, programming, motorcycle maintenance).\n" +
  "NOT a skill: one-off actions with nothing to teach ('Thawing Ice' - an action, not a skill), chores, events, states of being, products, brand names, or people's names. If it has no curriculum, it is not a skill.\n" +
  "\n" +
  "SAFETY GUIDELINES:\n" +
  "Reject anything unsafe or inappropriate regardless of phrasing: anything involving human remains or human-derived materials ('Preparing Human Meat' is rejected even though 'Preparing Meat' alone would be valid), illegal goods or services, weapons intended for harm, drugs, sexual content, violence, cruelty, or self-harm.\n" +
  "Filipino cultural and practical skills are the focus but not a hard requirement.";

async function jevCall(model: string, state: string, questions: unknown, admin: ReturnType<typeof createClient>) {
  let apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    // fallback: DB-stored secret (service-role only table)
    const { data } = await admin
      .from("integration_secrets")
      .select("value")
      .eq("name", "OPENROUTER_API_KEY")
      .maybeSingle();
    apiKey = (data as any)?.value ?? null;
  }
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "no key" }), {
      status: 503,
      headers: { "Content-Type": "application/json" },
    });
  }
  return fetch("https://openrouter.ai/api/v1/systemone", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model, state, questions }),
  });
}

async function placeSkill(
  admin: ReturnType<typeof createClient>,
  userId: string,
  skillId: string,
  kind: string,
  note: string | null,
): Promise<{ id: string | null; error: string | null }> {
  const { data, error } = await admin
    .from("user_skills")
    .insert({ user_id: userId, skill_id: skillId, kind, note })
    .select("id")
    .single();
  return { id: (data as any)?.id ?? null, error: error ? error.message : null };
}

const pick = (n: Record<string, unknown>) => ({ id: n.id, name: n.name, path: n.path });

async function log(
  admin: ReturnType<typeof createClient>,
  args: {
    user: string; name: string; note: string | null; answers: unknown;
    action: string; confidence: number | null; model: string;
    promptVersion: string; revision: number; cost?: number; stage: string;
  },
) {
  await admin.from("skill_moderation_log").insert({
    user_id: args.user,
    raw_input: args.name,
    note: args.note,
    verdict: args.answers as any,
    action: args.action,
    confidence: args.confidence,
    model: args.model,
    prompt_version: args.promptVersion,
    config_version: args.revision,
    cost_usd: args.cost ?? 0,
    stage: args.stage,
  });
}
