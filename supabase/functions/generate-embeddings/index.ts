// PalTuro — generate-embeddings Edge Function
// Recomputes profile passages (role x field-group) for the CALLING user and
// (re)embeds any that changed. Intended to be called after onboarding/profile edits.
// Uses NIM Llama Nemotron Embed VL 1B v2 (asymmetric: query + passage vectors stored).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { ensureFreshEmbeddings, getConfig, nimKey } from "../_shared/pipeline.ts";

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

    // verify caller (user JWT)
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: authData } = await userClient.auth.getUser();
    const user = authData?.user;
    if (!user) return json({ error: "Unauthorized" }, 401);

    const cfg = await getConfig(admin);
    const key = await nimKey(admin);
    if (!key) return json({ error: "NIM_API_KEY not configured" }, 503);

    const result = await ensureFreshEmbeddings(admin, [user.id], cfg, key);
    return json({
      status: "ok",
      user_id: user.id,
      embeddings_upserted: result.upserted,
      config_version: cfg.configRevision,
    });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});
