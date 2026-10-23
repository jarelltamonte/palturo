// PalTuro — delete-account Edge Function
// Permanently deletes the CALLING user: their storage media (recursively),
// their profile row (which cascades to profile-linked rows) and finally the
// auth user.
//
// The caller is identified from their JWT, so a user can only delete themselves.

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

const BUCKETS = ["profile-media", "skill-proofs", "avatars", "profile-photos", "skill-showcases"];
const PAGE = 100;

/** Recursively lists object keys under a prefix (Storage list is not recursive). */
async function listObjectPaths(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
  depth = 0,
): Promise<string[]> {
  if (depth > 6) throw new Error(`storage nesting too deep: ${bucket}/${prefix}`);

  const paths: string[] = [];
  let offset = 0;

  for (;;) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(prefix, { limit: PAGE, offset });

    if (error) {
      // A removed/renamed bucket has nothing to clean up.
      if (/not found/i.test(error.message)) return paths;
      throw new Error(`list ${bucket}/${prefix}: ${error.message}`);
    }

    const items = data ?? [];
    for (const item of items) {
      const path = `${prefix}/${item.name}`;
      // Virtual folders have no id and are not objects; recurse into them.
      if (item.id === null || item.id === undefined) {
        paths.push(...(await listObjectPaths(admin, bucket, path, depth + 1)));
      } else {
        paths.push(path);
      }
    }

    if (items.length < PAGE) break;
    offset += PAGE;
  }

  return paths;
}

async function deleteUserMedia(
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<void> {
  for (const bucket of BUCKETS) {
    const paths = await listObjectPaths(admin, bucket, userId);
    for (let i = 0; i < paths.length; i += PAGE) {
      const { error } = await admin.storage
        .from(bucket)
        .remove(paths.slice(i, i + PAGE));
      if (error) {
        throw new Error(`remove ${bucket}: ${error.message}`);
      }
    }
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Missing bearer token" }, 401);
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Identify the caller from their own JWT — never from the request body.
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: authData, error: authErr } = await userClient.auth.getUser();
    const user = authData?.user;
    if (authErr || !user) return json({ error: "Unauthorized" }, 401);

    const admin = createClient(url, serviceKey);

    const { data: rateOk, error: rateErr } = await admin.rpc(
      "consume_rate_limit",
      {
        p_subject: user.id,
        p_action: "delete_account",
        p_limit: 5,
        p_window_seconds: 3600,
      },
    );
    if (rateErr) {
      console.error(`[delete-account] rate limiter: ${rateErr.message}`);
      return json({ error: "rate_limit_unavailable" }, 503);
    }
    if (rateOk !== true) {
      return json({ error: "rate_limited", retry_after_seconds: 3600 }, 429);
    }

    // 1. Storage first. If this fails we abort before touching the database,
    //    so a failure never leaves a half-deleted account.
    await deleteUserMedia(admin, user.id);

    // 2. Profile row: removes the PII and cascades profile-linked rows.
    //    (profiles has no FK to auth.users, so it must be deleted explicitly.)
    const { error: profileErr } = await admin
      .from("profiles")
      .delete()
      .eq("id", user.id);
    if (profileErr) {
      console.error(`[delete-account] profile ${user.id}: ${profileErr.message}`);
      return json({ error: "Could not delete profile data. Please retry." }, 500);
    }

    // 3. Auth user last, so a partial failure can still be retried with the
    //    same JWT.
    const { error: deleteErr } = await admin.auth.admin.deleteUser(user.id);
    if (deleteErr) {
      console.error(`[delete-account] auth ${user.id}: ${deleteErr.message}`);
      return json(
        { error: "Profile data removed, but the account could not be closed. Please retry." },
        500,
      );
    }

    return json({ status: "ok" });
  } catch (e) {
    console.error(`[delete-account] ${(e as Error)?.message ?? e}`);
    return json({ error: "Unable to delete account. Please try again." }, 500);
  }
});
