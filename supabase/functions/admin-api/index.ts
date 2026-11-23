// PalTuro Admin API
// Server-side admin surface. The browser never receives a service-role key;
// every action verifies the caller's admin row, role, and MFA level here.

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  embedTexts,
  ensureFreshEmbeddings,
  getConfig,
  providerKey,
  PROVIDER_PRESETS,
  rerankTexts,
  resolveProvider,
} from "../_shared/pipeline.ts";

const CORS_BASE = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_ORIGINS = [
  "https://admin.palturo.app",
  "https://palturo-admin.pages.dev",
  "http://localhost:5173",
  "http://localhost:4173",
  "http://127.0.0.1:5173",
  "http://127.0.0.1:4173",
];

function originAllowed(origin: string): boolean {
  if (!origin) return true;
  const configured = (Deno.env.get("ADMIN_ORIGINS") ?? DEFAULT_ORIGINS.join(","))
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return configured.some((rule) =>
    rule.startsWith("*.")
      ? origin === rule.slice(2) || origin.endsWith(rule.slice(1))
      : origin === rule
  );
}

function corsFor(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...CORS_BASE,
    "Access-Control-Allow-Origin": origin && originAllowed(origin)
      ? origin
      : DEFAULT_ORIGINS[0],
    "Vary": "Origin",
  };
}

const send = (
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });

const ROLE_PERMISSIONS: Record<string, string[]> = {
  owner: ["*"],
  admin: [
    "analytics.read", "users.read", "users.write", "pii.read",
    "moderation.read", "moderation.write", "skills.read", "skills.write",
    "config.read", "config.write", "sandbox.run", "audit.read", "audit.revert",
    "backups.read", "backups.write",
    "exports.write", "saved_views.read", "saved_views.write", "admins.read",
  ],
  analyst: [
    "analytics.read", "users.read", "skills.read", "config.read",
    "sandbox.run", "audit.read", "exports.write",
    "saved_views.read", "saved_views.write",
  ],
  moderator: [
    "analytics.read", "users.read", "users.write", "moderation.read",
    "moderation.write", "skills.read", "skills.write", "audit.read",
    "exports.write", "saved_views.read", "saved_views.write",
  ],
  support: [
    "analytics.read", "users.read", "moderation.read", "skills.read",
    "audit.read", "exports.write", "saved_views.read", "saved_views.write",
  ],
};

const ACTION_PERMISSION: Record<string, string> = {
  overview: "analytics.read",
  analytics: "analytics.read",
  "users.list": "users.read",
  "users.detail": "users.read",
  "users.ban": "users.write",
  "users.unban": "users.write",
  "users.delete": "users.write",
  "users.resetMfa": "users.write",
  "users.cardVisibility": "users.write",
  "matcher.cardStats": "config.read",
  "matching.warm": "config.write",
  "moderation.reports": "moderation.read",
  "moderation.resolveReport": "moderation.write",
  "moderation.skills": "moderation.read",
  "moderation.skillAction": "moderation.write",
  "moderation.notes": "moderation.read",
  "moderation.noteAction": "moderation.write",
  "skills.list": "skills.read",
  "skills.detail": "skills.read",
  "skills.update": "skills.write",
  "skills.create": "skills.write",
  "skills.merge": "skills.write",
  "skills.import": "skills.write",
  "skills.move": "skills.write",
  "config.get": "config.read",
  "config.saveDraft": "config.write",
  "config.publish": "config.write",
  "embeddings.backfill": "config.write",
  "config.rollback": "config.write",
  "sandbox.run": "sandbox.run",
  "benchmark.inference": "sandbox.run",
  "sandbox.list": "sandbox.run",
  "sandbox.get": "sandbox.run",
  "audit.list": "audit.read",
  "audit.revert": "audit.revert",
  "backups.list": "backups.read",
  "backups.create": "backups.write",
  "backups.download": "backups.read",
  "backups.delete": "backups.write",
  "backups.verify": "backups.read",
  "backups.prune": "backups.write",
  "exports.log": "exports.write",
  "savedViews.list": "saved_views.read",
  "savedViews.save": "saved_views.write",
  "savedViews.delete": "saved_views.write",
  "admins.list": "admins.read",
  "admins.add": "admins.write",
  "admins.update": "admins.write",
  "admins.remove": "admins.write",
};

function decodeJwt(token: string): Record<string, any> {
  try {
    const part = token.split(".")[1] ?? "";
    return JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/")));
  } catch {
    return {};
  }
}

function can(role: string, permission: string): boolean {
  const list = ROLE_PERMISSIONS[role] ?? [];
  return list.includes("*") || list.includes(permission);
}

function maskEmail(value: string | null | undefined): string {
  if (!value) return "";
  const [name, domain] = value.split("@");
  if (!domain) return "***";
  return `${name.slice(0, 2)}***@${domain}`;
}

function clampInt(value: unknown, fallback: number, min: number, max: number): number {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(min, Math.min(max, Math.trunc(n))) : fallback;
}

function mapError(error: { message?: string } | null): string {
  return error?.message ?? "Unexpected error";
}

const BACKUP_BUCKET = "admin-backups";
const BACKUP_MAX_ROWS = 50000;
const BACKUP_GROUPS: Record<string, string[]> = {
  core: [
    "profiles",
    "user_skills",
    "skill_nodes",
    "connections",
    "messages",
    "skill_showcases",
  ],
  moderation: [
    "reports",
    "blocks",
    "moderation_actions",
    "note_moderation_queue",
    "skill_moderation_log",
    "feedback",
    "app_feedback",
  ],
  matching: [
    "pipeline_config",
    "pipeline_config_versions",
    "match_cache",
    "profile_embeddings",
  ],
  admin: [
    "admin_users",
    "admin_saved_views",
    "admin_exports",
    "admin_audit_log",
    "skill_change_log",
    "sandbox_runs",
    "sandbox_results",
  ],
};

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function selectAllRows(
  admin: any,
  table: string,
  maxRows = BACKUP_MAX_ROWS,
): Promise<{ rows: any[]; truncated: boolean }> {
  const rows: any[] = [];
  let offset = 0;
  for (;;) {
    const { data, error } = await admin
      .from(table)
      .select("*")
      .range(offset, offset + 999);
    if (error) throw new Error(`${table}: ${error.message}`);
    const batch = data ?? [];
    rows.push(...batch);
    if (batch.length < 1000) break;
    offset += 1000;
    if (rows.length >= maxRows) {
      return { rows: rows.slice(0, maxRows), truncated: true };
    }
  }
  return { rows, truncated: false };
}

async function moderationSnapshot(admin: any, userId: string) {
  const [{ data: profile }, { data: authUser }] = await Promise.all([
    admin
      .from("profiles")
      .select("moderation_status,suspended_at,warning_count,last_warned_at")
      .eq("id", userId)
      .maybeSingle(),
    admin.auth.admin.getUserById(userId),
  ]);
  return {
    profile: profile ?? null,
    banned_until: authUser?.user?.banned_until ?? null,
  };
}

async function activeOwnerCount(admin: any): Promise<number> {
  const { count } = await admin
    .from("admin_users")
    .select("*", { count: "exact", head: true })
    .eq("role", "owner")
    .eq("status", "active");
  return count ?? 0;
}

function isRevertible(row: { action: string; detail: any; reverted_at?: string | null }) {
  if (row.reverted_at) return false;
  const detail = row.detail ?? {};
  switch (row.action) {
    case "report.resolve":
      return Boolean(detail.before?.report);
    case "user.ban":
    case "user.unban":
      return Boolean(detail.before);
    case "skill.update":
    case "skill.approve":
    case "skill.reject":
    case "skill.retire":
      return Boolean(detail.before);
    case "skill.move":
      return Boolean(detail.before?.parent_id !== undefined);
    case "skill.create":
      return Boolean(detail.after?.id);
    case "skill.import":
      return Array.isArray(detail.node_ids) && detail.node_ids.length > 0;
    case "config.publish":
    case "config.rollback":
      return Boolean(detail.before_config);
    case "admin.add":
      return Boolean(row.detail?.target_id);
    case "admin.update":
    case "admin.remove":
      return Boolean(detail.before);
    default:
      return false;
  }
}

async function listStoragePaths(
  admin: any,
  bucket: string,
  prefix: string,
  depth = 0,
): Promise<string[]> {
  if (depth > 5) return [];
  const paths: string[] = [];
  let offset = 0;
  for (;;) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(prefix, { limit: 100, offset });
    if (error) {
      if (/not found/i.test(error.message)) return paths;
      throw error;
    }
    const items = data ?? [];
    for (const item of items) {
      const path = `${prefix}/${item.name}`;
      if (item.id === null || item.id === undefined) {
        paths.push(...(await listStoragePaths(admin, bucket, path, depth + 1)));
      } else {
        paths.push(path);
      }
    }
    if (items.length < 100) break;
    offset += 100;
  }
  return paths;
}

Deno.serve(async (req) => {
  const cors = corsFor(req);
  const json = (body: unknown, status = 200) => send(body, status, cors);
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const requestOrigin = req.headers.get("origin") ?? "";
  if (requestOrigin && !originAllowed(requestOrigin)) {
    return json({ error: "Origin not allowed" }, 403);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "Missing bearer token" }, 401);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: authData, error: authErr } = await userClient.auth.getUser();
  const user = authData?.user;
  if (authErr || !user) return json({ error: "Unauthorized" }, 401);

  const admin = createClient(url, serviceKey);
  const jwt = decodeJwt(authHeader.slice("Bearer ".length));
  const aal = jwt?.aal ?? "aal1";
  const { data: adminRow, error: adminErr } = await admin
    .from("admin_users")
    .select("*")
    .eq("user_id", user.id)
    .maybeSingle();
  if (adminErr) return json({ error: "Admin lookup failed" }, 500);
  if (!adminRow || adminRow.status !== "active") {
    return json({ error: "Admin access required" }, 403);
  }

  let payload: Record<string, any> = {};
  try {
    payload = await req.json();
  } catch {
    payload = {};
  }
  const action = String(payload.action ?? "session");
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  const userAgent = req.headers.get("user-agent") ?? "";
  const audit = async (
    act: string,
    targetType?: string | null,
    targetId?: string | null,
    detail?: unknown,
    reason?: string | null,
  ) => {
    await admin.from("admin_audit_log").insert({
      actor_id: user.id,
      actor_email: user.email,
      action: act,
      target_type: targetType ?? null,
      target_id: targetId ?? null,
      detail: detail ?? null,
      reason: reason ?? null,
      ip: ip || null,
      user_agent: userAgent || null,
    });
  };

  if (action === "session") {
    await admin
      .from("admin_users")
      .update({ last_login_at: new Date().toISOString() })
      .eq("user_id", user.id);
    return json({
      ok: true,
      data: {
        admin: {
          user_id: adminRow.user_id,
          role: adminRow.role,
          status: adminRow.status,
          mfa_required: adminRow.mfa_required,
          last_login_at: adminRow.last_login_at,
        },
        permissions: ROLE_PERMISSIONS[adminRow.role] ?? [],
        aal,
        email: user.email,
      },
    });
  }

  const permission = ACTION_PERMISSION[action];
  if (!permission) return json({ error: "Unknown action" }, 400);
  if (!can(adminRow.role, permission)) {
    return json({ error: "Insufficient permission" }, 403);
  }
  if (adminRow.mfa_required && aal !== "aal2") {
    return json({ error: "mfa_required" }, 403);
  }

  // A single admin console should never be able to hammer the API. 300
  // actions per minute is far above normal page use but bounds runaway loops.
  const { data: adminRateOk, error: adminRateErr } = await admin.rpc(
    "consume_rate_limit",
    {
      p_subject: user.id,
      p_action: "admin_api",
      p_limit: 300,
      p_window_seconds: 60,
    },
  );
  if (adminRateErr) {
    console.error(`[admin-api] rate limiter: ${adminRateErr.message}`);
    return json({ error: "rate_limit_unavailable" }, 503);
  }
  if (adminRateOk !== true) {
    return json({ error: "rate_limited" }, 429);
  }

  try {
    switch (action) {
      case "overview": {
        const { data, error } = await admin.rpc("admin_overview");
        if (error) throw error;
        return json({ ok: true, data });
      }

      // Matching analytics reads match_cache_v2, which only fills when a deck
      // is built. This rebuilds decks for onboarded users a batch at a time;
      // the console calls it repeatedly until `remaining` reaches zero.
      case "matching.warm": {
        const limit = clampInt(payload.limit, 6, 1, 20);
        const direction = String(payload.direction ?? "all");
        const roles =
          direction === "mentor" || direction === "learner"
            ? [direction]
            : ["mentor", "learner"];

        const { data: people, error: peopleErr } = await admin
          .from("profiles")
          .select("id")
          .eq("has_completed_onboarding", true)
          .order("last_seen_at", { ascending: false, nullsFirst: false })
          .limit(300);
        if (peopleErr) throw peopleErr;

        const functionUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/get-matches`;
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const started = Date.now();
        const warmed = new Set<string>();
        let skipped = 0;
        let failed = 0;
        const errors: string[] = [];

        for (const person of people ?? []) {
          if (warmed.size >= limit || Date.now() - started > 90_000) break;
          const id = String((person as Record<string, unknown>).id ?? "");
          if (!id) continue;

          for (const role of roles) {
            const { count } = await admin
              .from("match_cache_v2")
              .select("user_id", { count: "exact", head: true })
              .eq("user_id", id)
              .eq("as_role", role);
            if ((count ?? 0) > 0) {
              skipped += 1;
              continue;
            }

            try {
              const res = await fetch(functionUrl, {
                method: "POST",
                headers: {
                  Authorization: `Bearer ${serviceKey}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  as_role: role,
                  refresh: false,
                  warm_user: id,
                }),
              });
              if (!res.ok) {
                failed += 1;
                if (errors.length < 3) errors.push(`${role}: HTTP ${res.status}`);
              } else {
                warmed.add(id);
              }
            } catch (error) {
              failed += 1;
              if (errors.length < 3) {
                errors.push((error as Error)?.message ?? "warmup failed");
              }
            }
          }
        }

        return json({
          ok: true,
          data: {
            warmed: warmed.size,
            skipped,
            failed,
            errors,
            remaining: Math.max(
              0,
              (people?.length ?? 0) - skipped - warmed.size,
            ),
          },
        });
      }

      case "analytics": {        const surface = String(payload.surface ?? "growth");
        const days = clampInt(payload.days, 30, 1, 365);
        if (surface === "system") {
          const [baseResult, inferenceResult] = await Promise.all([
            admin.rpc("admin_system"),
            admin.rpc("admin_inference_system"),
          ]);
          if (baseResult.error) throw baseResult.error;
          if (inferenceResult.error) {
            console.error(
              `[admin-api] inference analytics: ${inferenceResult.error.message}`,
            );
          }
          return json({
            ok: true,
            data: {
              ...(baseResult.data ?? {}),
              inference: inferenceResult.error
                ? null
                : inferenceResult.data ?? null,
            },
            surface,
            days,
          });
        }
        const rpc =
          surface === "growth" ? "admin_growth"
          : surface === "users" ? "admin_user_analytics"
          : surface === "supply" ? "admin_supply"
          : surface === "matching" ? "admin_matching"
          : surface === "demographics" ? "admin_demographics"
          : surface === "conversations" ? "admin_conversations"
          : surface === "safety" ? "admin_safety"
          : surface === "activity" ? "admin_activity"
          : "";
        if (!rpc) return json({ error: "Unknown analytics surface" }, 400);
        const args =
          surface === "growth" ||
          surface === "conversations" ||
          surface === "activity" ||
          surface === "users"
            ? { p_days: days }
            : {};
        const { data, error } = await admin.rpc(rpc, args);
        if (error) throw error;
        return json({ ok: true, data, surface, days });
      }

      case "users.list": {
        const limit = clampInt(payload.limit, 25, 1, 100);
        const offset = clampInt(payload.offset, 0, 0, 100000);
        let query = admin
          .from("profiles")
          .select(
            "id,display_name,first_name,last_name,email,role,has_completed_onboarding,is_profile_completed,moderation_status,created_at,updated_at,teaching_skills,learning_skills",
            { count: "exact" },
          )
          .order("created_at", { ascending: false })
          .range(offset, offset + limit - 1);
        if (payload.role) query = query.eq("role", String(payload.role));
        if (payload.status) query = query.eq("moderation_status", String(payload.status));
        if (payload.search) {
          const q = String(payload.search)
            .replace(/[^a-zA-Z0-9 @._-]/g, "")
            .trim()
            .slice(0, 80);
          if (q) {
            const isUuid = /^[0-9a-f-]{36}$/i.test(q);
            query = isUuid
              ? query.or(`display_name.ilike.%${q}%,email.ilike.%${q}%,id.eq.${q}`)
              : query.or(`display_name.ilike.%${q}%,email.ilike.%${q}%`);
          }
        }
        const { data, error, count } = await query;
        if (error) throw error;
        const reveal = can(adminRow.role, "pii.read");
        return json({
          ok: true,
          data: (data ?? []).map((p: any) => ({
            ...p,
            email: reveal ? p.email : maskEmail(p.email),
            pii_masked: !reveal,
          })),
          total: count ?? 0,
        });
      }

      case "users.detail": {
        const id = String(payload.id ?? "");
        if (!id) return json({ error: "User id is required" }, 400);
        const reveal = can(adminRow.role, "pii.read");
        const [
          { data: profile },
          { data: skills },
          { data: reports },
          { data: auditRows },
          { data: authUser },
          { data: warnings },
          { data: accountWarnings },
        ] = await Promise.all([
          admin.from("profiles").select("*").eq("id", id).maybeSingle(),
          admin
            .from("user_skills")
            .select("id,kind,note,visibility,skill:skill_id(id,name,path,kind),focus:focus_skill_id(name)")
            .eq("user_id", id),
          admin
            .from("reports")
            .select(
              "id,reporter_id,reported_id,reason,details,status,created_at,resolved_at,messages_snapshot,action_taken,action_at",
            )
            .or(`reporter_id.eq.${id},reported_id.eq.${id}`)
            .order("created_at", { ascending: false })
            .limit(20),
          admin
            .from("admin_audit_log")
            .select("*")
            .eq("target_id", id)
            .order("created_at", { ascending: false })
            .limit(20),
          admin.auth.admin.getUserById(id),
          admin
            .from("moderation_actions")
            .select("id,action,reason,report_id,actor_id,created_at")
            .eq("user_id", id)
            .order("created_at", { ascending: false })
            .limit(50),
          admin
            .from("account_warnings")
            .select(
              "id,report_id,category,message,internal_reason,visible_days,visible_until,created_at,acknowledged_at,revoked_at,revoke_reason,issued_by",
            )
            .eq("user_id", id)
            .order("created_at", { ascending: false })
            .limit(50),
        ]);
        if (!profile) return json({ error: "User not found" }, 404);
        if (!reveal) profile.email = maskEmail(profile.email);
        if (reveal) {
          await audit("pii.reveal", "profile", id, { surface: "users.detail" });
        }
        return json({
          ok: true,
          data: {
            profile,
            skills: skills ?? [],
            reports: reports ?? [],
            warnings: warnings ?? [],
            account_warnings: accountWarnings ?? [],
            audit: auditRows ?? [],
            auth: authUser?.user
              ? {
                  id: authUser.user.id,
                  email: reveal ? authUser.user.email : maskEmail(authUser.user.email),
                  last_sign_in_at: authUser.user.last_sign_in_at,
                  banned_until: authUser.user.banned_until,
                  email_confirmed_at: authUser.user.email_confirmed_at,
                }
              : null,
            pii_masked: !reveal,
          },
        });
      }

      case "users.ban":
      case "users.unban": {
        const id = String(payload.id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id) return json({ error: "User id is required" }, 400);
        if (!reason) return json({ error: "A reason is required" }, 400);
        if (id === user.id) {
          return json({ error: "You cannot suspend or restore your own account" }, 409);
        }
        const { data: targetAdmin } = await admin
          .from("admin_users")
          .select("role")
          .eq("user_id", id)
          .maybeSingle();
        if (targetAdmin) {
          if (adminRow.role !== "owner") {
            return json({ error: "Only an owner can change another admin's auth state" }, 403);
          }
          if (targetAdmin.role === "owner") {
            const { count } = await admin
              .from("admin_users")
              .select("*", { count: "exact", head: true })
              .eq("role", "owner")
              .eq("status", "active");
            if ((count ?? 0) <= 1) {
              return json({ error: "Cannot suspend the last active owner" }, 409);
            }
          }
        }
        const ban = action === "users.ban";
        const before = await moderationSnapshot(admin, id);
        const { error: authMutation } = await admin.auth.admin.updateUserById(id, {
          ban_duration: ban ? "876000h" : "none",
        });
        if (authMutation) throw authMutation;
        const afterProfile = {
          moderation_status: ban ? "suspended" : "active",
          suspended_at: ban ? new Date().toISOString() : null,
        };
        const { error: profileMutation } = await admin
          .from("profiles")
          .update(afterProfile)
          .eq("id", id);
        if (profileMutation) throw profileMutation;
        await admin.from("match_cache").delete().or(`user_id.eq.${id},candidate_id.eq.${id}`);
        await audit(
          ban ? "user.ban" : "user.unban",
          "profile",
          id,
          { before, after: afterProfile },
          reason,
        );
        return json({ ok: true, data: { id, status: ban ? "suspended" : "active" } });
      }

      case "users.delete": {
        const id = String(payload.id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id) return json({ error: "User id is required" }, 400);
        if (!reason) return json({ error: "A reason is required" }, 400);
        if (id === user.id) {
          return json({ error: "You cannot delete your own account" }, 409);
        }
        const { data: targetAdmin } = await admin
          .from("admin_users")
          .select("role")
          .eq("user_id", id)
          .maybeSingle();
        if (targetAdmin && adminRow.role !== "owner") {
          return json({ error: "Only an owner can delete an admin account" }, 403);
        }
        if (targetAdmin?.role === "owner") {
          const { count } = await admin
            .from("admin_users")
            .select("*", { count: "exact", head: true })
            .eq("role", "owner")
            .eq("status", "active");
          if ((count ?? 0) <= 1) {
            return json({ error: "Cannot delete the last active owner" }, 409);
          }
        }
        const buckets = ["profile-media", "skill-proofs", "avatars", "profile-photos", "skill-showcases"];
        for (const bucket of buckets) {
          const paths = await listStoragePaths(admin, bucket, id);
          for (let i = 0; i < paths.length; i += 100) {
            await admin.storage.from(bucket).remove(paths.slice(i, i + 100));
          }
        }
        const { error: profileErr } = await admin.from("profiles").delete().eq("id", id);
        if (profileErr) throw profileErr;
        const { error: authErr } = await admin.auth.admin.deleteUser(id);
        if (authErr) throw authErr;
        await audit("user.delete", "profile", id, null, reason);
        return json({ ok: true, data: { id } });
      }

      case "users.resetMfa": {
        const id = String(payload.id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "User id and reason are required" }, 400);
        const { data: targetAdmin } = await admin
          .from("admin_users")
          .select("role")
          .eq("user_id", id)
          .maybeSingle();
        if (targetAdmin?.role === "owner" && adminRow.role !== "owner") {
          return json({ error: "Only an owner can reset another owner's MFA" }, 403);
        }
        const { error } = await admin.rpc("admin_clear_mfa", { p_user: id });
        if (error) throw error;
        await audit("user.reset_mfa", "profile", id, null, reason);
        return json({ ok: true, data: { id } });
      }

      case "users.cardVisibility": {
        const cardId = String(payload.card_id ?? "");
        const visibility = String(payload.visibility ?? "");
        if (!cardId) return json({ error: "Card id is required" }, 400);
        if (!["discoverable", "paused", "hidden"].includes(visibility)) {
          return json(
            { error: "visibility must be discoverable, paused, or hidden" },
            400,
          );
        }
        const { data: card, error } = await admin
          .from("user_skills")
          .update({ visibility })
          .eq("id", cardId)
          .select("id,user_id,kind,visibility")
          .maybeSingle();
        if (error) throw error;
        if (!card) return json({ error: "Card not found" }, 404);
        await audit(
          "user.card_visibility",
          "user_skill",
          cardId,
          { user_id: (card as any).user_id, visibility },
          null,
        );
        return json({ ok: true, data: card });
      }

      case "moderation.reports": {
        const { data, error } = await admin
          .from("reports")
          .select(
            "id,reporter_id,reported_id,reason,details,status,created_at,resolved_at,assigned_to,messages_snapshot,action_taken,action_by,action_at,reporter:reporter_id(id,display_name,email),reported:reported_id(id,display_name,email,moderation_status,warning_count),assigned:assigned_to(id,display_name)",
          )
          .order("created_at", { ascending: false })
          .limit(200);
        if (error) throw error;
        const reveal = can(adminRow.role, "pii.read");
        const rows = (data ?? []).map((r: any) => ({
          ...r,
          reporter: r.reporter
            ? { ...r.reporter, email: reveal ? r.reporter.email : maskEmail(r.reporter.email) }
            : null,
          reported: r.reported
            ? { ...r.reported, email: reveal ? r.reported.email : maskEmail(r.reported.email) }
            : null,
        }));
        return json({ ok: true, data: rows });
      }

      case "moderation.resolveReport": {
        const id = String(payload.id ?? "");
        const status = String(payload.status ?? "reviewed");
        const actionTaken = String(payload.moderation_action ?? "pass").toLowerCase();
        const resolution = String(payload.resolution ?? "").trim();
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Report id and reason are required" }, 400);
        if (!["open", "reviewed", "dismissed", "actioned"].includes(status)) {
          return json({ error: "Invalid report status" }, 400);
        }
        if (!["pass", "warn", "suspend", "ban"].includes(actionTaken)) {
          return json({ error: "Invalid moderation action" }, 400);
        }

        const warningDays = clampInt(payload.warning_days, 30, 1, 365);
        const warningCategoryRaw = String(payload.warning_category ?? "other").toLowerCase();
        const warningCategory = ["spam", "harassment", "irrelevant", "other"].includes(
          warningCategoryRaw,
        )
          ? warningCategoryRaw
          : "other";
        const warningMessage =
          String(payload.warning_message ?? "").trim() ||
          "A moderator reviewed a report about your account and found it did not follow the PalTuro community guidelines. Please review the guidelines; repeated violations can lead to suspension.";

        const { data: report } = await admin
          .from("reports")
          .select("*")
          .eq("id", id)
          .maybeSingle();
        if (!report) return json({ error: "Report not found" }, 404);

        const reportedId = report.reported_id as string | null;
        if (!reportedId) {
          return json({ error: "Report has no target profile" }, 409);
        }
        if (actionTaken !== "pass" && reportedId === user.id) {
          return json({ error: "You cannot action your own account" }, 409);
        }

        const { data: targetAdmin } = await admin
          .from("admin_users")
          .select("role")
          .eq("user_id", reportedId)
          .maybeSingle();
        if (targetAdmin && actionTaken !== "pass" && adminRow.role !== "owner") {
          return json({ error: "Only an owner can action another admin" }, 403);
        }
        if (
          targetAdmin?.role === "owner" &&
          (actionTaken === "suspend" || actionTaken === "ban")
        ) {
          if ((await activeOwnerCount(admin)) <= 1) {
            return json({ error: "Cannot suspend or ban the last active owner" }, 409);
          }
        }

        const before = await moderationSnapshot(admin, reportedId);
        let userAfter: any = before.profile;
        let warningResult: any = null;
        const now = new Date().toISOString();

        if (actionTaken === "warn") {
          const { data: warning, error } = await admin.rpc("admin_issue_warning", {
            p_user: reportedId,
            p_report: id,
            p_category: warningCategory,
            p_message: warningMessage,
            p_internal_reason: reason,
            p_visible_days: warningDays,
            p_actor: user.id,
          });
          if (error) throw error;
          warningResult = warning;
          const { data, error: profileError } = await admin
            .from("profiles")
            .select("moderation_status,suspended_at,warning_count,last_warned_at")
            .eq("id", reportedId)
            .single();
          if (profileError) throw profileError;
          userAfter = data;
        } else if (actionTaken === "suspend" || actionTaken === "ban") {
          const { error: authError } = await admin.auth.admin.updateUserById(reportedId, {
            ban_duration: actionTaken === "ban" ? "876000h" : "720h",
          });
          if (authError) throw authError;
          const nextStatus = actionTaken === "ban" ? "banned" : "suspended";
          const { data, error } = await admin
            .from("profiles")
            .update({ moderation_status: nextStatus, suspended_at: now })
            .eq("id", reportedId)
            .select("moderation_status,suspended_at,warning_count,last_warned_at")
            .single();
          if (error) throw error;
          userAfter = data;
          await admin.from("match_cache").delete().or(`user_id.eq.${reportedId},candidate_id.eq.${reportedId}`);
        }

        const { error: actionError } = await admin.from("moderation_actions").insert({
          report_id: id,
          user_id: reportedId,
          action: actionTaken,
          reason,
          actor_id: user.id,
        });
        if (actionError) throw actionError;

        const afterReport = {
          status,
          resolution: resolution || null,
          assigned_to: user.id,
          resolved_at: status === "open" ? null : now,
          action_taken: actionTaken,
          action_by: user.id,
          action_at: now,
        };
        const { error } = await admin
          .from("reports")
          .update(afterReport)
          .eq("id", id);
        if (error) throw error;

        await audit(
          "report.resolve",
          "report",
          id,
          {
            before: { report, user: before },
            after: { report: afterReport, user: userAfter },
            action: actionTaken,
            warning: warningResult,
          },
          reason,
        );
        return json({
          ok: true,
          data: { action: actionTaken, user: userAfter, warning: warningResult },
        });
      }

      case "moderation.skills": {
        const { data, error } = await admin
          .from("skill_nodes")
          .select(
            "id,name,path,kind,status,origin,auto_approved,approval_source,is_visible,is_general,depth,created_at,parent:parent_id(id,name,path,kind),submitted:submitted_by(id,display_name)",
          )
          .eq("status", "pending")
          .order("created_at", { ascending: true })
          .limit(200);
        if (error) throw error;
        return json({ ok: true, data: data ?? [] });
      }

      case "moderation.skillAction": {
        const id = String(payload.id ?? "");
        const decision = String(payload.decision ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Skill id and reason are required" }, 400);
        if (!["approve", "reject", "retire"].includes(decision)) {
          return json({ error: "Invalid skill decision" }, 400);
        }
        const status = decision === "approve" ? "approved" : decision === "reject" ? "rejected" : "retired";
        const { data: before } = await admin.from("skill_nodes").select("*").eq("id", id).maybeSingle();
        if (!before) return json({ error: "Skill not found" }, 404);
        const after = {
          status,
          is_visible: decision === "approve",
          auto_approved: false,
          approval_source: "manual",
          updated_at: new Date().toISOString(),
        };
        const { error } = await admin
          .from("skill_nodes")
          .update(after)
          .eq("id", id);
        if (error) throw error;
        await admin.from("skill_change_log").insert({
          node_id: id,
          action: decision,
          before,
          after,
          reason,
          actor_id: user.id,
        });
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit(`skill.${decision}`, "skill_node", id, { before, after }, reason);
        return json({ ok: true });
      }

      case "moderation.notes": {
        const status = String(payload.status ?? "pending");
        let query = admin
          .from("note_moderation_queue")
          .select(
            "id,user_id,kind,name,skill_id,note,status,decision_source,attempts,last_error,created_at,updated_at,user:user_id(id,display_name,email),skill:skill_id(id,name,path)",
          )
          .order("created_at", { ascending: true })
          .limit(200);
        if (status !== "all") query = query.eq("status", status);
        const { data, error } = await query;
        if (error) throw error;
        const reveal = can(adminRow.role, "pii.read");
        return json({
          ok: true,
          data: (data ?? []).map((row: any) => ({
            ...row,
            user: row.user
              ? { ...row.user, email: reveal ? row.user.email : maskEmail(row.user.email) }
              : null,
          })),
          pii_masked: !reveal,
        });
      }

      case "moderation.noteAction": {
        const id = String(payload.id ?? "");
        const decision = String(payload.decision ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Note id and reason are required" }, 400);
        if (!["approve", "reject"].includes(decision)) {
          return json({ error: "Invalid note decision" }, 400);
        }
        const status = decision === "approve" ? "approved" : "rejected";
        const { data: before } = await admin
          .from("note_moderation_queue")
          .select("*")
          .eq("id", id)
          .maybeSingle();
        if (!before) return json({ error: "Note not found" }, 404);
        const { error } = await admin
          .from("note_moderation_queue")
          .update({
            status,
            decision_source: "manual",
            updated_at: new Date().toISOString(),
          })
          .eq("id", id);
        if (error) throw error;

        // Publish or withdraw the note itself. The queue row is only audit
        // state; public output reads user_skills.note_approved.
        if (before.skill_id) {
          const { error: noteErr } = await admin
            .from("user_skills")
            .update({
              note_approved: decision === "approve",
              note_approval_source:
                decision === "approve" ? "manual" : null,
              updated_at: new Date().toISOString(),
            })
            .eq("user_id", before.user_id)
            .eq("kind", before.kind)
            .eq("skill_id", before.skill_id)
            .eq("note", before.note);
          if (noteErr) throw noteErr;
        }

        if (before.user_id) {
          try {
            const cfg = await getConfig(admin as any);
            const key = await providerKey(admin as any, cfg.embedProvider);
            if (key) {
              await ensureFreshEmbeddings(admin as any, [before.user_id], cfg, key);
            }
          } catch (refreshError) {
            console.error(
              `[admin-api] note embedding refresh: ${
                (refreshError as Error)?.message ?? refreshError
              }`,
            );
          }
        }

        await audit(`note.${decision}`, "note", id, { status, user_id: before.user_id }, reason);
        return json({ ok: true, data: { id, status } });
      }

      case "skills.list": {
        const boolValue = (value: unknown): boolean | null => {
          if (value === true || value === "true") return true;
          if (value === false || value === "false") return false;
          return null;
        };
        let query = admin
          .from("skill_nodes")
          .select(
            "id,name,path,depth,kind,status,origin,auto_approved,approval_source,is_visible,is_general,is_leaf,usage_count,created_at,updated_at,parent:parent_id(id,name),submitted_by",
          )
          .order("path")
          .limit(clampInt(payload.limit, 5000, 1, 5000));
        if (payload.search) {
          const q = String(payload.search)
            .replace(/[^a-zA-Z0-9 @._-]/g, "")
            .trim()
            .slice(0, 80);
          if (q) query = query.ilike("name", `%${q}%`);
        }
        for (const key of ["kind", "status", "origin", "approval_source", "parent_id"]) {
          if (payload[key]) query = query.eq(key, String(payload[key]));
        }
        const visible = boolValue(payload.is_visible);
        if (visible !== null) query = query.eq("is_visible", visible);
        const general = boolValue(payload.is_general);
        if (general !== null) query = query.eq("is_general", general);
        const autoApproved = boolValue(payload.auto_approved);
        if (autoApproved !== null) query = query.eq("auto_approved", autoApproved);
        if (payload.depth !== undefined) {
          query = query.eq("depth", clampInt(payload.depth, 1, 1, 10));
        }
        if (payload.min_usage !== undefined) {
          query = query.gte("usage_count", clampInt(payload.min_usage, 0, 0, 1000000));
        }
        const { data, error } = await query;
        if (error) throw error;
        return json({ ok: true, data: data ?? [] });
      }

      case "skills.detail": {
        const id = String(payload.id ?? "");
        if (!id) return json({ error: "Skill id is required" }, 400);
        const { data: node, error: nodeError } = await admin
          .from("skill_nodes")
          .select("*,parent:parent_id(id,name)")
          .eq("id", id)
          .maybeSingle();
        if (nodeError) throw nodeError;
        if (!node) return json({ error: "Skill not found" }, 404);

        const { data: allNodes, error: nodesError } = await admin
          .from("skill_nodes")
          .select("id,name,path,parent_id,depth,kind,status,is_visible")
          .order("path")
          .limit(5000);
        if (nodesError) throw nodesError;

        const subtree = (allNodes ?? []).filter(
          (item: any) =>
            item.path === node.path ||
            String(item.path).startsWith(`${node.path}.`),
        );
        const ids = subtree.map((item: any) => item.id);
        const children = (allNodes ?? []).filter(
          (item: any) => item.parent_id === id,
        );

        const userRows: any[] = [];
        for (let offset = 0; offset < ids.length; offset += 100) {
          const chunk = ids.slice(offset, offset + 100);
          const { data, error } = await admin
            .from("user_skills")
            .select(
              "id,user_id,kind,note,focus_skill_id,skill:skill_id(id,name,path,kind),focus:focus_skill_id(name),user:user_id(id,display_name,email,role,avatar_url,moderation_status)",
            )
            .in("skill_id", chunk)
            .limit(1000);
          if (error) throw error;
          userRows.push(...(data ?? []));
        }

        const reveal = can(adminRow.role, "pii.read");
        const users = userRows
          .filter((row: any) => row.user)
          .map((row: any) => ({
            ...row,
            user: {
              ...row.user,
              email: reveal ? row.user.email : maskEmail(row.user.email),
            },
          }))
          .sort((a: any, b: any) =>
            String(a.user.display_name ?? a.user.email ?? "").localeCompare(
              String(b.user.display_name ?? b.user.email ?? ""),
            ),
          );

        const distinct = new Set(users.map((row: any) => row.user_id));
        const mentors = new Set(
          users.filter((row: any) => row.kind === "teach").map((row: any) => row.user_id),
        );
        const learners = new Set(
          users.filter((row: any) => row.kind === "learn").map((row: any) => row.user_id),
        );

        return json({
          ok: true,
          data: {
            node,
            descendants: Math.max(0, subtree.length - 1),
            children,
            users,
            counts: {
              users: distinct.size,
              mentors: mentors.size,
              learners: learners.size,
              rows: users.length,
            },
            truncated: users.length >= 1000,
            pii_masked: !reveal,
          },
        });
      }

      case "skills.update": {
        const id = String(payload.id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Skill id and reason are required" }, 400);
        const { data: before } = await admin.from("skill_nodes").select("*").eq("id", id).maybeSingle();
        if (!before) return json({ error: "Skill not found" }, 404);

        const allowed: Record<string, any> = {};
        for (const key of ["name", "status", "is_visible", "is_general", "approval_source", "auto_approved"]) {
          if (payload[key] !== undefined) allowed[key] = payload[key];
        }
        if (Object.keys(allowed).length === 0) return json({ error: "No fields to update" }, 400);
        if (allowed.status !== undefined && !["approved", "pending", "rejected", "retired"].includes(allowed.status)) {
          return json({ error: "Invalid status" }, 400);
        }
        if (
          allowed.approval_source !== undefined &&
          !["inference", "manual", "seed", "import"].includes(allowed.approval_source)
        ) {
          return json({ error: "Invalid approval source" }, 400);
        }

        let renameResult: any = null;
        if (allowed.name !== undefined) {
          const nextName = String(allowed.name).trim();
          if (!nextName) return json({ error: "Name must not be empty" }, 400);
          delete allowed.name;
          if (nextName !== before.name) {
            const { data, error } = await admin.rpc("admin_rename_skill", {
              p_node: id,
              p_name: nextName,
              p_actor: user.id,
              p_reason: reason,
            });
            if (error) return json({ error: error.message }, 409);
            renameResult = data;
          }
        }

        if (Object.keys(allowed).length > 0) {
          allowed.updated_at = new Date().toISOString();
          const { error } = await admin.from("skill_nodes").update(allowed).eq("id", id);
          if (error) return json({ error: error.message }, 409);
        }

        const after = { ...allowed, ...(renameResult ? { name: String(payload.name).trim(), path: renameResult.path } : {}) };
        await admin.from("skill_change_log").insert({
          node_id: id,
          action: "update",
          before,
          after,
          reason,
          actor_id: user.id,
        });
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit("skill.update", "skill_node", id, { before, after }, reason);
        return json({ ok: true, data: { id, ...after } });
      }

      case "skills.create": {
        const name = String(payload.name ?? "").trim();
        const parentId = String(payload.parent_id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!name || !parentId || !reason) {
          return json({ error: "Name, parent, and reason are required" }, 400);
        }
        const { data: parent, error: parentErr } = await admin
          .from("skill_nodes")
          .select("id,name,kind")
          .eq("id", parentId)
          .maybeSingle();
        if (parentErr || !parent) return json({ error: "Parent not found" }, 404);
        const kind = parent.kind === "category" ? "skill" : "focus";
        const { data, error } = await admin
          .from("skill_nodes")
          .insert({
            name,
            parent_id: parentId,
            kind,
            is_leaf: true,
            is_visible: true,
            origin: "official",
            status: "approved",
            auto_approved: false,
            approval_source: "manual",
          })
          .select("id,name,path,kind,status,approval_source")
          .single();
        if (error) return json({ error: error.message }, 409);
        await admin.from("skill_change_log").insert({
          node_id: data.id,
          action: "create",
          before: null,
          after: data,
          reason,
          actor_id: user.id,
        });
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit("skill.create", "skill_node", data.id, { after: data }, reason);
        return json({ ok: true, data });
      }

      case "skills.merge": {
        const source = String(payload.source_id ?? "");
        const target = String(payload.target_id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!source || !target || !reason) {
          return json({ error: "Source, target, and reason are required" }, 400);
        }
        const { data, error } = await admin.rpc("admin_merge_skills", {
          p_source: source,
          p_target: target,
          p_actor: user.id,
          p_reason: reason,
        });
        if (error) return json({ error: error.message }, 409);
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit("skill.merge", "skill_node", source, { target, ...data }, reason);
        return json({ ok: true, data });
      }

      case "skills.import": {
        const items = Array.isArray(payload.items) ? payload.items : [];
        const reason = String(payload.reason ?? "").trim();
        if (!reason) return json({ error: "A reason is required" }, 400);
        const { data: nodes } = await admin.from("skill_nodes").select("id,name,path,kind");
        const byPath = new Map((nodes ?? []).map((n: any) => [String(n.path), n]));
        let inserted = 0;
        let skipped = 0;
        const nodeIds: string[] = [];
        for (const item of items.slice(0, 500)) {
          const name = String(item.name ?? "").trim();
          const parentPath = String(item.parent_path ?? "").trim();
          if (!name || !parentPath) { skipped++; continue; }
          const parent: any = byPath.get(parentPath);
          if (!parent) { skipped++; continue; }
          const kind = parent.kind === "category" ? "skill" : "focus";
          const { data, error } = await admin
            .from("skill_nodes")
            .insert({
              name,
              parent_id: parent.id,
              kind,
              is_leaf: true,
              is_visible: item.is_visible !== false,
              origin: "official",
              status: item.status === "pending" ? "pending" : "approved",
              auto_approved: false,
              approval_source: "import",
            })
            .select("id,name,path,kind,status,approval_source")
            .single();
          if (error) { skipped++; continue; }
          inserted++;
          nodeIds.push(data.id);
          byPath.set(String(data.path), data);
          await admin.from("skill_change_log").insert({
            node_id: data.id,
            action: "import",
            before: null,
            after: data,
            reason,
            actor_id: user.id,
          });
        }
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit("skill.import", "skill_nodes", null, { inserted, skipped, node_ids: nodeIds }, reason);
        return json({ ok: true, data: { inserted, skipped, node_ids: nodeIds } });
      }

      case "skills.move": {
        const id = String(payload.id ?? "");
        const parentId = payload.parent_id ? String(payload.parent_id) : null;
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Skill id and reason are required" }, 400);
        const { data: before } = await admin
          .from("skill_nodes")
          .select("*")
          .eq("id", id)
          .maybeSingle();
        if (!before) return json({ error: "Skill not found" }, 404);
        const { data, error } = await admin.rpc("admin_move_skill", {
          p_node: id,
          p_new_parent: parentId,
          p_actor: user.id,
          p_reason: reason,
        });
        if (error) return json({ error: error.message }, 409);
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit("skill.move", "skill_node", id, { before, after: data }, reason);
        return json({ ok: true, data });
      }

      case "matcher.cardStats": {
        const head = { count: "exact" as const, head: true };
        const [
          cards,
          teach,
          learn,
          discoverable,
          paused,
          hidden,
          emb,
          profEmb,
          cacheV2,
          modeRow,
        ] = await Promise.all([
          admin.from("user_skills").select("*", head),
          admin.from("user_skills").select("*", head).eq("kind", "teach"),
          admin.from("user_skills").select("*", head).eq("kind", "learn"),
          admin.from("user_skills").select("*", head).eq("visibility", "discoverable"),
          admin.from("user_skills").select("*", head).eq("visibility", "paused"),
          admin.from("user_skills").select("*", head).eq("visibility", "hidden"),
          admin.from("card_embeddings").select("card_id,input_type"),
          admin.from("profile_embeddings").select("*", head),
          admin.from("match_cache_v2").select("*", head),
          admin
            .from("pipeline_config")
            .select("value")
            .eq("key", "matcher_mode")
            .maybeSingle(),
        ]);
        const embRows = (emb.data ?? []) as Array<{
          card_id: string;
          input_type: string;
        }>;
        const embeddedCards = new Set(embRows.map((r) => r.card_id)).size;
        const embeddedPassages = embRows.filter((r) => r.input_type === "passage").length;
        const totalCards = cards.count ?? 0;
        return json({
          ok: true,
          data: {
            matcher_mode: modeRow.data?.value ?? "profile",
            cards: totalCards,
            teach: teach.count ?? 0,
            learn: learn.count ?? 0,
            discoverable: discoverable.count ?? 0,
            paused: paused.count ?? 0,
            hidden: hidden.count ?? 0,
            embedded_cards: embeddedCards,
            embedded_passages: embeddedPassages,
            card_embedding_rows: embRows.length,
            coverage: totalCards > 0 ? embeddedPassages / totalCards : 0,
            profile_embeddings: profEmb.count ?? 0,
            card_cache_rows: cacheV2.count ?? 0,
          },
        });
      }

      case "config.get": {
        const [{ data: config }, { data: versions }] = await Promise.all([
          admin.from("pipeline_config").select("key,value,description,updated_at").order("key"),
          admin
            .from("pipeline_config_versions")
            .select("*")
            .order("created_at", { ascending: false })
            .limit(25),
        ]);
        const values: Record<string, unknown> = {};
        for (const row of config ?? []) {
          if (row.key !== "__revision") values[row.key] = row.value;
        }
        // Report which provider keys exist so the editor can warn before a
        // provider is selected without credentials. This is advisory; the
        // runtime degrades to the other provider or basic_bi instead of
        // failing the publish.
        const { data: secretRows } = await admin
          .from("integration_secrets")
          .select("name")
          .in("name", ["NIM_API_KEY", "DEEPINFRA_API_KEY"]);
        const names = new Set((secretRows ?? []).map((r: any) => r.name));
        const providers = {
          nvidia: Boolean(Deno.env.get("NIM_API_KEY")) || names.has("NIM_API_KEY"),
          deepinfra:
            Boolean(Deno.env.get("DEEPINFRA_API_KEY")) ||
            names.has("DEEPINFRA_API_KEY"),
        };
        return json({
          ok: true,
          data: {
            config: config ?? [],
            values,
            providers,
            revision: Number(
              (config ?? []).find((r: any) => r.key === "__revision")?.value ?? 0,
            ),
            versions: versions ?? [],
          },
        });
      }

      case "config.saveDraft": {
        const label = String(payload.label ?? "").trim() || `Draft ${new Date().toISOString()}`;
        const config = payload.config;
        const notes = String(payload.notes ?? "").trim() || null;
        if (!config || typeof config !== "object") return json({ error: "Config object is required" }, 400);
        const { data, error } = await admin
          .from("pipeline_config_versions")
          .insert({ label, config, notes, created_by: user.id })
          .select("id,label,created_at")
          .single();
        if (error) throw error;
        await audit("config.draft", "pipeline_config_version", data.id, { label }, notes);
        return json({ ok: true, data });
      }

      case "config.publish":
      case "config.rollback": {
        let config: Record<string, any> | null = null;
        let versionId: string | null = null;
        let reason = String(payload.reason ?? "").trim();
        if (action === "config.rollback") {
          versionId = String(payload.version_id ?? "");
          if (!versionId) return json({ error: "Version id is required" }, 400);
          const { data: version } = await admin
            .from("pipeline_config_versions")
            .select("*")
            .eq("id", versionId)
            .maybeSingle();
          if (!version) return json({ error: "Version not found" }, 404);
          config = version.config;
          reason = reason || `Rollback to ${version.label}`;
        } else {
          config = payload.config;
          versionId = payload.version_id ? String(payload.version_id) : null;
        }
        if (!config || typeof config !== "object" || Array.isArray(config)) {
          return json({ error: "Config object is required" }, 400);
        }
        if (!reason) return json({ error: "A reason is required" }, 400);
        const clean: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(config)) {
          if (key === "__revision") continue;
          clean[key] = value;
        }
        const { data: currentRows } = await admin
          .from("pipeline_config")
          .select("key,value");
        const beforeConfig: Record<string, unknown> = {};
        let beforeRevision = 0;
        for (const row of currentRows ?? []) {
          if (row.key === "__revision") beforeRevision = Number(row.value ?? 0);
          else beforeConfig[row.key] = row.value;
        }
        // Each operation owns its provider, and the provider owns the endpoint
        // and model names. Normalise them here so a publish or rollback cannot
        // leave SQL reading a different model than the functions embed/rerank
        // with. Resolution order:
        //   1. the submitted per-operation key;
        //   2. a legacy single-provider payload (neither per-op key present),
        //      which applies to both operations;
        //   3. the stored provider for that operation.
        // That keeps old snapshots rollback-able and lets a partial payload
        // change one selector without flipping the other.
        // `inference_provider` is kept for backwards compatibility and mirrors
        // the embedding provider.
        const hasPerOpProvider =
          clean.embed_provider != null || clean.rerank_provider != null;
        const legacyProvider = hasPerOpProvider
          ? undefined
          : clean.inference_provider;
        const embedProvider = resolveProvider(
          clean.embed_provider ??
            legacyProvider ??
            beforeConfig.embed_provider ??
            beforeConfig.inference_provider,
        );
        const rerankProvider = resolveProvider(
          clean.rerank_provider ??
            legacyProvider ??
            beforeConfig.rerank_provider ??
            beforeConfig.inference_provider,
        );
        const embedPreset = PROVIDER_PRESETS[embedProvider];
        const rerankPreset = PROVIDER_PRESETS[rerankProvider];
        clean.embed_provider = embedProvider;
        clean.rerank_provider = rerankProvider;
        clean.inference_provider = embedProvider;
        clean.embedding_model = embedPreset.embeddingModel;
        clean.embedding_api = embedPreset.embeddingApi;
        clean.rerank_model = rerankPreset.rerankModel;
        clean.rerank_api = rerankPreset.rerankApi;
        const fallbackRaw = String(
          clean.rerank_fallback_provider ?? "deepinfra",
        ).trim().toLowerCase();
        let fallback = ["none", "nvidia", "deepinfra"].includes(fallbackRaw)
          ? fallbackRaw
          : "none";
        if (fallback !== "none" && fallback === rerankProvider) {
          // A fallback equal to the primary is a no-op; store the explicit
          // disabled value so the admin UI does not advertise a second path.
          fallback = "none";
        }
        clean.rerank_fallback_provider = fallback;
        const thresholdRaw = clean.rerank_failure_threshold;
        clean.rerank_failure_threshold =
          thresholdRaw == null || thresholdRaw === ""
            ? 3
            : clampInt(thresholdRaw, 3, 1, 20);
        const cooldownRaw = clean.rerank_cooldown_seconds;
        clean.rerank_cooldown_seconds =
          cooldownRaw == null || cooldownRaw === ""
            ? 60
            : clampInt(cooldownRaw, 60, 10, 600);
        if (Object.keys(clean).length === 0) {
          return json({ error: "Config must not be empty" }, 400);
        }
        const { data: published, error: publishErr } = await admin.rpc(
          "admin_publish_config",
          {
            p_config: clean,
            p_actor: user.id,
            p_reason: reason,
            p_version_id: versionId,
            p_label: payload.label ? String(payload.label) : null,
          },
        );
        if (publishErr) return json({ error: publishErr.message }, 409);
        const beforeModel = String(beforeConfig.embedding_model ?? "");
        const nextModel = String(clean.embedding_model ?? "");
        const embeddingsReset = Boolean(
          nextModel && beforeModel && nextModel !== beforeModel,
        );
        if (embeddingsReset) {
          // Vectors from the previous model are meaningless to the new one.
          // match_candidates also filters by model, but removing them keeps
          // every consumer (including possible-match) consistent.
          const { error: purgeErr } = await admin
            .from("profile_embeddings")
            .delete()
            .neq("model_name", nextModel);
          if (purgeErr) {
            console.error(
              `[admin-api] stale embedding purge: ${purgeErr.message}`,
            );
          }
        }
        await admin.from("match_cache").delete().gte("rank", 0);
        await admin.from("match_cache_v2").delete().gte("rank", 0);
        await audit(
          action === "config.rollback" ? "config.rollback" : "config.publish",
          "pipeline_config",
          String(published?.revision ?? ""),
          {
            version_id: published?.version_id ?? versionId,
            before_config: beforeConfig,
            before_revision: beforeRevision,
            after_revision: published?.revision ?? null,
          },
          reason,
        );
        return json({ ok: true, data: { ...published, embeddings_reset: embeddingsReset } });
      }

      case "embeddings.backfill": {
        const cfg = await getConfig(admin as any);
        const key = await providerKey(admin as any, cfg.embedProvider);
        if (!key) {
          return json(
            { error: "inference_key_missing", provider: cfg.embedProvider },
            503,
          );
        }
        const limit = clampInt(payload.limit, 50, 1, 200);
        const offset = clampInt(payload.offset, 0, 0, 100000);
        const { data: rows, error } = await admin
          .from("profiles")
          .select("id")
          .eq("has_completed_onboarding", true)
          .order("id")
          .range(offset, offset + limit - 1);
        if (error) throw error;
        const ids = (rows ?? []).map((r: any) => r.id as string);
        let upserted = 0;
        const batchSize = 10;
        for (let i = 0; i < ids.length; i += batchSize) {
          const batch = ids.slice(i, i + batchSize);
          try {
            const res = await ensureFreshEmbeddings(
              admin as any,
              batch,
              cfg,
              key,
              30000,
            );
            upserted += res.upserted;
          } catch (e) {
            const detail = String((e as Error)?.message ?? e).slice(0, 300);
            console.error(`[admin-api] embeddings backfill: ${detail}`);
            return json(
              {
                error: "embedding_backfill_failed",
                detail,
                processed: i,
                upserted,
              },
              502,
            );
          }
        }
        await audit(
          "embeddings.backfill",
          "profile",
          String(ids.length),
          { provider: cfg.embedProvider, offset, limit, upserted },
          null,
        );
        return json({
          ok: true,
          data: {
            provider: cfg.embedProvider,
            processed: ids.length,
            upserted,
            next_offset: ids.length === limit ? offset + limit : null,
          },
        });
      }

      case "benchmark.inference": {
        const provider = resolveProvider(payload.provider);
        const preset = PROVIDER_PRESETS[provider];
        const operation = String(payload.operation ?? "embed");
        if (!["embed", "rerank"].includes(operation)) {
          return json({ error: "operation must be embed or rerank" }, 400);
        }
        const size = clampInt(payload.size, 8, 1, 64);
        const iterations = clampInt(payload.iterations, 3, 1, 10);
        const concurrency = clampInt(payload.concurrency, 1, 1, 8);
        const base = await getConfig(admin as any);
        const cfg: any = {
          ...base,
          embedProvider: provider,
          rerankProvider: provider,
          embedProviderLabel:
            provider === "deepinfra" ? "DeepInfra" : "NVIDIA NIM",
          rerankProviderLabel:
            provider === "deepinfra" ? "DeepInfra" : "NVIDIA NIM",
          embedSecretName: preset.secretName,
          rerankSecretName: preset.secretName,
          rerankStyle: preset.rerankStyle,
          embeddingModel: preset.embeddingModel,
          embeddingApi: preset.embeddingApi,
          rerankModel: preset.rerankModel,
          rerankApi: preset.rerankApi,
        };
        const key = await providerKey(admin as any, provider);
        if (!key) {
          return json(
            { error: "inference_key_missing", provider },
            503,
          );
        }
        const words = [
          "cooking", "weaving", "guitar", "adobo", "patterns", "harvest",
          "market", "lesson", "practice", "family", "barangay", "teacher",
          "learner", "schedule", "weekend", "language", "design", "repair",
          "garden", "recipe",
        ];
        const makeText = (n: number, seed: number) =>
          Array.from(
            { length: n },
            (_, i) => words[(seed + i * 7) % words.length],
          ).join(" ");
        const runOne = async () => {
          const started = performance.now();
          if (operation === "embed") {
            const texts = Array.from({ length: size }, (_, i) =>
              makeText(40 + (i % 10), i),
            );
            const vectors = await embedTexts(key, cfg, texts, "passage", 30000);
            return { ms: performance.now() - started, units: vectors.length };
          }
          const query = makeText(18, 3);
          const docs = Array.from({ length: size }, (_, i) =>
            makeText(50 + (i % 12), i + 1),
          );
          const ranked = await rerankTexts(key, cfg, query, docs, 30000);
          return { ms: performance.now() - started, units: ranked.length };
        };

        const errors: string[] = [];
        try {
          await runOne(); // warm-up: TLS, provider cold start
        } catch (e) {
          errors.push(String((e as Error)?.message ?? e).slice(0, 200));
        }
        const samples: number[] = [];
        let units = 0;
        const wallStart = performance.now();
        for (let round = 0; round < iterations; round++) {
          const results = await Promise.allSettled(
            Array.from({ length: concurrency }, () => runOne()),
          );
          for (const result of results) {
            if (result.status === "fulfilled") {
              samples.push(result.value.ms);
              units += result.value.units;
            } else {
              errors.push(
                String(result.reason?.message ?? result.reason).slice(0, 200),
              );
            }
          }
        }
        const wallMs = performance.now() - wallStart;
        const sorted = [...samples].sort((a, b) => a - b);
        const percentile = (p: number) =>
          sorted.length
            ? sorted[Math.min(sorted.length - 1, Math.floor(p * (sorted.length - 1)))]
            : null;
        await audit(
          "benchmark.inference",
          "provider",
          `${provider}:${operation}`,
          { size, iterations, concurrency, requests: samples.length },
          null,
        );
        return json({
          ok: true,
          data: {
            provider,
            operation,
            size,
            iterations,
            concurrency,
            wall_ms: wallMs,
            requests: samples.length,
            error_count: errors.length,
            min_ms: sorted[0] ?? null,
            p50_ms: percentile(0.5),
            p95_ms: percentile(0.95),
            max_ms: sorted[sorted.length - 1] ?? null,
            units_total: units,
            throughput_per_s: wallMs > 0 ? (samples.length * 1000) / wallMs : null,
            samples_ms: samples,
            errors: errors.slice(0, 3),
          },
        });
      }

      case "sandbox.run": {
        const sampleSize = clampInt(payload.sample_size, 50, 1, 500);
        const candidateConfig = payload.candidate_config;
        if (!candidateConfig || typeof candidateConfig !== "object") {
          return json({ error: "Candidate config is required" }, 400);
        }
        const stageInput = (payload.stages ?? {}) as Record<string, unknown>;
        const stages = {
          score: stageInput.score !== false,
          gate: stageInput.gate !== false,
          embeddings: stageInput.embeddings === true,
          moderation: stageInput.moderation === true,
        };
        // Production floors the final score at the bi-encoder similarity. Off
        // is a hypothetical: it shows what the rerank parameters would do on
        // their own, which is the only way they can move a rank.
        const applyBiFloor = payload.apply_bi_floor !== false;
        const { data: currentConfig } = await admin
          .from("pipeline_config")
          .select("key,value");
        const baselineRevision = Number(
          (currentConfig ?? []).find((r: any) => r.key === "__revision")?.value ?? 0,
        );

        // Every key is compared, not just the simulated ones. The report says
        // what the replay can measure and what only takes effect after a
        // rebuild (vectors, models, moderation).
        const impactOf = (key: string): string => {
          if (
            [
              "reciprocal_formula",
              "rerank_a_weight",
              "rerank_b_weight",
              "rerank_b_limit",
              "max_deck_size",
              "min_final_score",
              "max_per_user",
              "max_per_skill",
            ].includes(key)
          ) {
            return "deck_scoring";
          }
          if (["min_skill_score", "require_discovery_media", "embedding_weights"].includes(key)) {
            return "retrieval_gate";
          }
          if (
            [
              "embed_provider",
              "embedding_model",
              "embedding_api",
              "embedding_dim",
              "inference_provider",
            ].includes(key)
          ) {
            return "embedding_space";
          }
          if (
            [
              "rerank_provider",
              "rerank_model",
              "rerank_api",
              "rerank_fallback_provider",
              "rerank_template",
              "rerank_b_concurrency",
              "rerank_budget_ms",
              "rerank_a_timeout_ms",
              "rerank_b_timeout_ms",
              "rerank_failure_threshold",
              "rerank_cooldown_seconds",
            ].includes(key)
          ) {
            return "rerank_runtime";
          }
          if (
            key.startsWith("decision_") ||
            key.startsWith("note_") ||
            key === "moderation_guidelines"
          ) {
            return "moderation";
          }
          if (key.startsWith("possible_match")) return "possible_match";
          if (key.startsWith("get_matches_rate")) return "rate_limits";
          if (["calibration", "worker_url"].includes(key)) return "reserved";
          return "other";
        };

        const sameConfigValue = (a: unknown, b: unknown): boolean => {
          if (JSON.stringify(a) === JSON.stringify(b)) return true;
          if (a === null || b === null || a === undefined || b === undefined) return false;
          if (
            (a === true || a === "true") &&
            (b === true || b === "true")
          ) {
            return true;
          }
          if (
            (a === false || a === "false") &&
            (b === false || b === "false")
          ) {
            return true;
          }
          const na = Number(a);
          const nb = Number(b);
          return Number.isFinite(na) && Number.isFinite(nb) && na === nb;
        };

        const IMMEDIATE = new Set(["deck_scoring", "retrieval_gate"]);
        const baselineValues = new Map<string, unknown>(
          (currentConfig ?? []).map((row: any) => [String(row.key), row.value]),
        );
        const candidateValues = new Map<string, unknown>(
          Object.entries(candidateConfig as Record<string, unknown>),
        );
        const keys = new Set<string>([
          ...baselineValues.keys(),
          ...candidateValues.keys(),
        ]);
        const diffRows: Array<{
          key: string;
          baseline: unknown;
          candidate: unknown;
          impact: string;
        }> = [];
        for (const key of keys) {
          if (key === "__revision") continue;
          const before = baselineValues.get(key) ?? null;
          const after = candidateValues.has(key)
            ? candidateValues.get(key)
            : before;
          if (sameConfigValue(before, after)) continue;
          diffRows.push({ key, baseline: before, candidate: after, impact: impactOf(key) });
        }
        const impactLabels: Record<string, string> = {
          deck_scoring: "Deck scoring",
          retrieval_gate: "Retrieval gate",
          embedding_space: "Embedding space",
          rerank_runtime: "Rerank runtime",
          moderation: "Moderation",
          possible_match: "Possible-match",
          rate_limits: "Rate limits",
          reserved: "Reserved",
          other: "Other",
        };
        const impactNotes: Record<string, string> = {
          deck_scoring: "Measured by the score replay below.",
          retrieval_gate: "Measured by the skill-gate replay on the sandbox snapshot.",
          embedding_space:
            "Changes the vectors themselves. Nothing in this replay applies until every profile and card is re-embedded.",
          rerank_runtime:
            "Model, template, timeouts and budget are not replayed; they change live cost and latency.",
          moderation:
            "Applies to classify-skill and moderate-notes. It does not change an existing deck.",
          possible_match:
            "SQL worker settings for notifications; the replay does not model fan-out.",
          rate_limits: "Throttling only; no effect on the pair set.",
          reserved: "No runtime reader, or rewritten by the publisher from provider presets.",
          other: "No simulation path.",
        };
        const configDiff = {
          changed: diffRows.length,
          rows: diffRows.sort(
            (a, b) =>
              (IMMEDIATE.has(a.impact) ? 0 : 1) - (IMMEDIATE.has(b.impact) ? 0 : 1) ||
              a.key.localeCompare(b.key),
          ),
          by_impact: diffRows.reduce<Record<string, number>>((acc, row) => {
            acc[row.impact] = (acc[row.impact] ?? 0) + 1;
            return acc;
          }, {}),
          notes: Object.keys(impactLabels)
            .map((id) => ({
              id,
              label: impactLabels[id],
              note: impactNotes[id],
              changed: diffRows.filter((row) => row.impact === id).length,
            }))
            .filter((note) => note.changed > 0),
        };

        const { data: run, error: runErr } = await admin
          .from("sandbox_runs")
          .insert({
            actor_id: user.id,
            sample_size: sampleSize,
            baseline_revision: baselineRevision,
            candidate_config: candidateConfig,
            status: "running",
          })
          .select("id,started_at")
          .single();
        if (runErr) throw runErr;

        try {
          // Cards mode writes match_cache_v2; the legacy cache only holds
          // profile/gated rows. Replay whichever the matcher is currently
          // filling, preferring v2.
          const { count: v2Count } = await admin
            .from("match_cache_v2")
            .select("user_id", { count: "exact", head: true });
          const useCards = (v2Count ?? 0) > 0;
          let cacheQuery = admin
            .from(useCards ? "match_cache_v2" : "match_cache")
            .select(
              "user_id,as_role,candidate_id,rank,bi_score,rerank_score_a,rerank_score_b,calibrated_score,pipeline_mode" +
                (useCards ? ",candidate_card_id,skill_name,skill_path" : ""),
            )
            .order("user_id")
            .limit(10000);
          const roleFilter = String(payload.as_role ?? "");
          if (roleFilter === "mentor" || roleFilter === "learner") {
            cacheQuery = cacheQuery.eq("as_role", roleFilter);
          }
          const { data: cache, error: cacheErr } = await cacheQuery;
          if (cacheErr) throw cacheErr;

          if (!cache || cache.length === 0) {
            const message =
              "No cached pairs to replay. Build decks first from Matching → Warm cache, then run the sandbox.";
            await admin
              .from("sandbox_runs")
              .update({
                status: "failed",
                error: message,
                finished_at: new Date().toISOString(),
              })
              .eq("id", run.id);
            return json({ error: message }, 409);
          }

          const aWeight = Number(candidateConfig.rerank_a_weight ?? 0.6);
          const bWeight = Number(candidateConfig.rerank_b_weight ?? 0.4);
          const formula = String(candidateConfig.reciprocal_formula ?? "geometric_mean");
          const bLimit = clampInt(candidateConfig.rerank_b_limit, 10, 0, 500);
          const deckCap = clampInt(candidateConfig.max_deck_size, 20, 1, 100);
          // Thresholds and diversity caps are part of the deck the user sees,
          // so they must move the replay too.
          const minFinal = Number(candidateConfig.min_final_score ?? 0);
          const perUserCap = clampInt(candidateConfig.max_per_user, 0, 0, 50);
          const perSkillCap = clampInt(candidateConfig.max_per_skill, 0, 0, 100);
          const groups = new Map<string, any[]>();
          for (const row of cache ?? []) {
            const key = `${row.user_id}|${row.as_role}`;
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key)!.push(row);
          }
          const selected = [...groups.entries()].slice(0, sampleSize);
          const results: any[] = [];
          let users = 0;
          let candidates = 0;
          let changed = 0;
          let improved = 0;
          let worsened = 0;
          let top10Overlap = 0;
          let top10New = 0;
          let top10Dropped = 0;
          let scoreDeltaTotal = 0;
          let candidateAOnly = 0;
          let absRankShiftTotal = 0;
          let maxRankShift = 0;
          let correlationTotal = 0;
          let correlationDecks = 0;
          let cappedCandidates = 0;
          let droppedByThreshold = 0;
          let cappedByUser = 0;
          let cappedBySkill = 0;
          let flooredRows = 0;
          let biTotal = 0;
          let reciprocalTotal = 0;

          // Cards mode caches one row per card, so rank and baseline lookups
          // key on the card when it is available.
          const keyOf = (row: any) =>
            String(row.candidate_card_id ?? row.candidate_id);

          const scoreOf = (row: any, aRank: number) => {
            const bi = Math.max(Number(row.bi_score ?? 0), 0);
            const pa = row.rerank_score_a === null ? null : Number(row.rerank_score_a);
            let pb = row.rerank_score_b === null ? null : Number(row.rerank_score_b);
            if (aRank > bLimit) pb = null;
            let reciprocal: number;
            if (pa !== null && pb !== null) {
              const a = Math.max(0, Math.min(1, pa));
              const b = Math.max(0, Math.min(1, pb));
              switch (formula) {
                case "arithmetic_mean":
                  reciprocal = (a + b) / 2;
                  break;
                case "weighted_mean": {
                  const total = aWeight + bWeight;
                  reciprocal = total > 0 ? (aWeight * a + bWeight * b) / total : (a + b) / 2;
                  break;
                }
                case "harmonic_mean":
                  reciprocal = a + b > 0 ? (2 * a * b) / (a + b) : 0;
                  break;
                case "min":
                  reciprocal = Math.min(a, b);
                  break;
                case "geometric_mean":
                default:
                  reciprocal = Math.sqrt(a * b);
                  break;
              }
            } else if (pa !== null) {
              reciprocal = pa;
            } else {
              reciprocal = bi;
            }
            // Cards mode floors the final score at the bi-encoder similarity so
            // a compressed rerank cannot empty a valid deck. Without this the
            // replay scores ~0.08 and drops every row.
            row.__bi = bi;
            row.__reciprocal = reciprocal;
            return applyBiFloor && useCards ? Math.max(reciprocal, bi) : reciprocal;
          };

          if (stages.score) for (const [, rows] of selected) {
            users++;            const aSorted = [...rows].sort(
              (a, b) => Number(b.rerank_score_a ?? -1) - Number(a.rerank_score_a ?? -1),
            );
            const aRank = new Map(aSorted.map((r, i) => [keyOf(r), i + 1]));
            const baseline = new Map(rows.map((r) => [keyOf(r), r]));
            const scored = aSorted.map((row) => {
              const candidate_score = scoreOf(row, aRank.get(keyOf(row)) ?? 999);
              // scoreOf annotates the row; the spread must not happen first or
              // the annotations are lost and the floor metrics read as zero.
              return {
                ...row,
                candidate_score,
                __bi: row.__bi,
                __reciprocal: row.__reciprocal,
              };
            });
            scored.sort((a, b) => b.candidate_score - a.candidate_score);

            const eligible =
              Number.isFinite(minFinal) && minFinal > 0
                ? scored.filter((row) => row.candidate_score >= minFinal)
                : scored;
            droppedByThreshold += scored.length - eligible.length;

            const deckScored: any[] = [];
            const perUserSeen = new Map<string, number>();
            const perSkillSeen = new Map<string, number>();
            for (const row of eligible) {
              if (deckScored.length >= deckCap) break;
              const userKey = String(row.candidate_id);
              const skillKey = String((row as any).skill_name ?? "");
              if (perUserCap > 0 && (perUserSeen.get(userKey) ?? 0) >= perUserCap) {
                cappedByUser += 1;
                continue;
              }
              if (perSkillCap > 0 && skillKey && (perSkillSeen.get(skillKey) ?? 0) >= perSkillCap) {
                cappedBySkill += 1;
                continue;
              }
              perUserSeen.set(userKey, (perUserSeen.get(userKey) ?? 0) + 1);
              if (skillKey) perSkillSeen.set(skillKey, (perSkillSeen.get(skillKey) ?? 0) + 1);
              deckScored.push(row);
            }
            cappedCandidates += Math.max(0, eligible.length - deckScored.length);

            if (deckScored.length > 1) {
              const candidateRankMap = new Map(
                deckScored.map((row, index) => [keyOf(row), index + 1]),
              );
              let d2 = 0;
              for (const row of deckScored) {
                const d = Number(row.rank) - Number(candidateRankMap.get(keyOf(row)) ?? 0);
                d2 += d * d;
              }
              const n = deckScored.length;
              correlationTotal += 1 - (6 * d2) / (n * (n * n - 1));
              correlationDecks++;
            }

            deckScored.forEach((row, index) => {
              const candidateRank = index + 1;
              const baselineRank = Number(row.rank);
              const baselineScore = Number(row.calibrated_score);
              const delta = Number((row.candidate_score - baselineScore).toFixed(6));
              candidates++;
              if (row.rerank_score_b === null) candidateAOnly++;
              biTotal += Number(row.__bi ?? 0);
              reciprocalTotal += Number(row.__reciprocal ?? 0);
              if (Number(row.__bi ?? 0) >= Number(row.__reciprocal ?? 0)) flooredRows++;
              scoreDeltaTotal += delta;
              const rankShift = Math.abs(candidateRank - baselineRank);
              absRankShiftTotal += rankShift;
              if (rankShift > maxRankShift) maxRankShift = rankShift;
              if (candidateRank !== baselineRank) {
                changed++;
                if (candidateRank < baselineRank) improved++;
                else worsened++;
                if (candidateRank <= 10 || baselineRank <= 10) {
                  results.push({
                    user_id: row.user_id,
                    as_role: row.as_role,
                    candidate_id: row.candidate_id,
                    baseline_rank: baselineRank,
                    candidate_rank: candidateRank,
                    baseline_score: baselineScore,
                    candidate_score: Number(row.candidate_score.toFixed(6)),
                    delta,
                  });
                }
              }
              const baseEntry = baseline.get(keyOf(row));
              const baseTop = baseEntry && Number(baseEntry.rank) <= 10;
              const nextTop = candidateRank <= 10;
              if (baseTop && nextTop) top10Overlap++;
              if (!baseTop && nextTop) top10New++;
              if (baseTop && !nextTop) top10Dropped++;
            });
          }

          // Retrieval gate simulation. match_cards is cheap and deterministic,
          // so the published and candidate skill gates can both run for the
          // sampled decks and their pair sets compared. This is the only way to
          // see pairs the published gate never fetched (for example lowering
          // min_skill_score to admit siblings).
          const configValue = (key: string) =>
            (currentConfig ?? []).find((row: any) => row.key === key)?.value;
          const asNumber = (value: unknown, fallback: number) => {
            const n = Number(value);
            return Number.isFinite(n) ? n : fallback;
          };
          const asBool = (value: unknown, fallback: boolean) => {
            if (typeof value === "boolean") return value;
            if (value === "true") return true;
            if (value === "false") return false;
            return fallback;
          };
          const publishedWeights = (configValue("embedding_weights") ?? {}) as Record<string, unknown>;
          const candidateWeights = (candidateConfig.embedding_weights ?? {}) as Record<string, unknown>;
          const baselineMinSkill = asNumber(configValue("min_skill_score"), 0.5);
          const candidateMinSkill = asNumber(candidateConfig.min_skill_score, baselineMinSkill);
          const baselineMedia = asBool(configValue("require_discovery_media"), true);
          const candidateMedia = asBool(candidateConfig.require_discovery_media, baselineMedia);
          const baselineWeights = {
            skills: asNumber(publishedWeights.skills, 0.7),
            context: asNumber(publishedWeights.context, 0.3),
          };
          const candidateWeightValues = {
            skills: asNumber(candidateWeights.skills, baselineWeights.skills),
            context: asNumber(candidateWeights.context, baselineWeights.context),
          };

          const gate = {
            decks: 0,
            baseline_pairs: 0,
            candidate_pairs: 0,
            kept_pairs: 0,
            new_pairs: 0,
            removed_pairs: 0,
            min_skill_baseline: baselineMinSkill,
            min_skill_candidate: candidateMinSkill,
            media_baseline: baselineMedia,
            media_candidate: candidateMedia,
            weights_candidate: candidateWeightValues,
          };
          const cardKeys = (pairs: any[]) =>
            new Set(pairs.map((pair) => String(pair.card_id ?? "")));

          // The gate replay runs against the sandbox snapshot, never the live
          // matching tables. Refresh is TTL-bounded so repeat runs are cheap.
          const { error: refreshErr } = await admin.rpc("sandbox_refresh", {
            p_max_age_seconds: 600,
          });
          if (refreshErr) {
            console.error(`[admin-api] sandbox snapshot: ${refreshErr.message}`);
          }

          // Optional heavy stage: re-embed the snapshot with the candidate
          // provider/model, then let the gate replay read the new vectors.
          const embeddingStage = {
            requested: stages.embeddings,
            embedded: 0,
            skipped: "",
            errors: [] as string[],
            model: "",
            dimension: 1024,
          };
          if (stages.embeddings) {
            const provider = String(
              candidateConfig.embed_provider ?? configValue("embed_provider") ?? "deepinfra",
            );
            const embedModel = String(
              candidateConfig.embedding_model ?? configValue("embedding_model") ?? "",
            );
            const embedApi = String(
              candidateConfig.embedding_api ?? configValue("embedding_api") ?? "",
            );
            const dimension = asNumber(
              candidateConfig.embedding_dim ?? configValue("embedding_dim"),
              1024,
            );
            const embedKey =
              provider === "nvidia"
                ? Deno.env.get("NIM_API_KEY")
                : Deno.env.get("DEEPINFRA_API_KEY");
            embeddingStage.model = embedModel;
            embeddingStage.dimension = dimension;
            if (dimension !== 1024) {
              embeddingStage.skipped = "sandbox vectors are fixed at 1024 dimensions";
            } else if (!embedKey) {
              embeddingStage.skipped = `no ${provider} embedding key configured`;
            } else if (!embedApi || !embedModel) {
              embeddingStage.skipped = "embedding endpoint or model missing";
            } else {
              const readers = [
                {
                  read: "sandbox_profile_texts",
                  write: "sandbox_set_profile_embeddings",
                  keyOf: (row: any) => ({
                    user_id: row.user_id,
                    role: row.role,
                    field_group: row.field_group,
                    input_type: row.input_type,
                  }),
                },
                {
                  read: "sandbox_card_texts",
                  write: "sandbox_set_card_embeddings",
                  keyOf: (row: any) => ({
                    card_id: row.card_id,
                    input_type: row.input_type,
                  }),
                },
              ];
              const fitVector = (vector: number[], dim: number): number[] => {
                if (vector.length === dim) return vector;
                if (vector.length > dim) {
                  // Matryoshka models return the full width; the leading
                  // dimensions are the usable prefix, re-normalised.
                  const cut = vector.slice(0, dim);
                  const norm = Math.sqrt(cut.reduce((sum, value) => sum + value * value, 0));
                  return norm > 0 ? cut.map((value) => value / norm) : cut;
                }
                throw new Error(`expected ${dim} dimensions, got ${vector.length}`);
              };

              for (const reader of readers) {
                let offset = 0;
                while (offset < 600) {
                  const { data: rows, error: readErr } = await admin.rpc(reader.read, {
                    p_offset: offset,
                    p_limit: 16,
                  });
                  if (readErr || !rows || rows.length === 0) break;

                  // Query and passage vectors must be embedded as their own
                  // kind, so a page is split by input_type before calling out.
                  const byType = new Map<string, any[]>();
                  for (const row of rows) {
                    const inputType = String((row as any).input_type ?? "passage");
                    if (!byType.has(inputType)) byType.set(inputType, []);
                    byType.get(inputType)!.push(row);
                  }

                  for (const [inputType, group] of byType) {
                    const res = await fetch(embedApi, {
                      method: "POST",
                      headers: {
                        Authorization: `Bearer ${embedKey}`,
                        "Content-Type": "application/json",
                      },
                      body: JSON.stringify({
                        input: group.map((row) => row.source_text),
                        model: embedModel,
                        dimensions: dimension,
                        ...(provider === "deepinfra"
                          ? { encoding_format: "float" }
                          : {}),
                        input_type: inputType,
                      }),
                    });
                    if (!res.ok) {
                      embeddingStage.errors.push(
                        `${reader.read} (${inputType}): HTTP ${res.status}`,
                      );
                      continue;
                    }
                    const body = await res.json();
                    const vectors = (body?.data ?? []) as Array<{ embedding: number[] }>;
                    if (vectors.length !== group.length) {
                      embeddingStage.errors.push(
                        `${reader.read} (${inputType}): vector count mismatch`,
                      );
                      continue;
                    }
                    let fitted: number[][];
                    try {
                      fitted = vectors.map((vector) => fitVector(vector.embedding, dimension));
                    } catch (error) {
                      embeddingStage.errors.push(
                        `${reader.read}: ${(error as Error).message}`,
                      );
                      continue;
                    }
                    const items = group.map((row, index) => ({
                      ...reader.keyOf(row),
                      model_name: embedModel,
                      embedding: fitted[index],
                    }));
                    const { error: writeErr } = await admin.rpc(reader.write, {
                      p_items: items,
                    });
                    if (writeErr) {
                      embeddingStage.errors.push(`${reader.read}: ${writeErr.message}`);
                      continue;
                    }
                    embeddingStage.embedded += group.length;
                  }

                  offset += rows.length;
                  if (rows.length < 16) break;
                }
              }
            }
          }

          if (stages.gate) for (const [groupKey] of selected.slice(0, 20)) {
            const [gateUser, gateRole] = groupKey.split("|");
            if (!gateUser || (gateRole !== "mentor" && gateRole !== "learner")) continue;
            const runGate = (
              minSkill: number,
              media: boolean,
              weights: { skills: number; context: number },
            ) =>
              admin.rpc("sandbox_match_cards", {
                p_user: gateUser,
                p_target: gateRole,
                p_limit: 500,
                p_min_skill: minSkill,
                p_require_media: media,
                p_w_skills: weights.skills,
                p_w_context: weights.context,
              });
            const [baselineGate, candidateGate] = await Promise.all([
              runGate(baselineMinSkill, baselineMedia, baselineWeights),
              runGate(candidateMinSkill, candidateMedia, candidateWeightValues),
            ]);
            if (baselineGate.error || candidateGate.error) continue;
            const base = cardKeys((baselineGate.data ?? []) as any[]);
            const cand = cardKeys((candidateGate.data ?? []) as any[]);
            gate.decks += 1;
            gate.baseline_pairs += base.size;
            gate.candidate_pairs += cand.size;
            for (const cardKey of cand) {
              if (base.has(cardKey)) gate.kept_pairs += 1;
              else gate.new_pairs += 1;
            }
            for (const cardKey of base) {
              if (!cand.has(cardKey)) gate.removed_pairs += 1;
            }
          }

          const scoredKeys = [
            "reciprocal_formula",
            "rerank_a_weight",
            "rerank_b_weight",
            "rerank_b_limit",
            "max_deck_size",
            "min_final_score",
            "max_per_user",
            "max_per_skill",
            "min_skill_score",
            "require_discovery_media",
            "embedding_weights",
          ];
          const ignoredKeys = Object.keys(candidateConfig).filter(
            (key) => !scoredKeys.includes(key) && key !== "__revision",
          );
          const summary = {
            users,
            candidates,
            changed,
            improved,
            worsened,
            top10_overlap: top10Overlap,
            top10_new: top10New,
            top10_dropped: top10Dropped,
            top10_overlap_pct:
              top10Overlap + top10New + top10Dropped > 0
                ? top10Overlap / (top10Overlap + top10New + top10Dropped)
                : null,
            // No surviving rows is not "no change": every ratio is undefined
            // rather than a perfect 1.0, so the console can say why.
            avg_score_delta: candidates ? scoreDeltaTotal / candidates : null,
            changed_share: candidates ? changed / candidates : null,
            avg_abs_rank_shift: candidates ? absRankShiftTotal / candidates : null,
            max_rank_shift: maxRankShift,
            rank_correlation:
              correlationDecks > 0 ? correlationTotal / correlationDecks : null,
            a_only_share: candidates ? candidateAOnly / candidates : 0,
            floored_share: candidates ? flooredRows / candidates : 0,
            avg_bi: candidates ? biTotal / candidates : 0,
            avg_reciprocal: candidates ? reciprocalTotal / candidates : 0,
            formula,
            b_limit: bLimit,
            deck_cap: deckCap,
            min_final_score: Number.isFinite(minFinal) ? minFinal : 0,
            max_per_user: perUserCap,
            max_per_skill: perSkillCap,
            dropped_by_threshold: droppedByThreshold,
            capped_by_user: cappedByUser,
            capped_by_skill: cappedBySkill,
            gate,
            stages,
            bi_floor_applied: applyBiFloor,
            embeddings: embeddingStage,
            config_diff: configDiff,
            capped_candidates: cappedCandidates,
            as_role: roleFilter || "all",
            baseline_rows: (cache ?? []).length,
            simulated_keys: scoredKeys,
            ignored_keys: ignoredKeys,
            note: "Cached-score replay plus a live skill-gate replay. The bi floor, formula, weights, B limit, final-score threshold, per-user/per-skill caps, deck sizing, min_skill_score, require_discovery_media and embedding weights are simulated; embeddings, rerank models, and timeouts are not.",
          };
          await admin
            .from("sandbox_runs")
            .update({
              status: "complete",
              summary,
              finished_at: new Date().toISOString(),
            })
            .eq("id", run.id);
          if (results.length) {
            const limited = results.slice(0, 1000).map((r) => ({ ...r, run_id: run.id }));
            for (let i = 0; i < limited.length; i += 500) {
              await admin.from("sandbox_results").insert(limited.slice(i, i + 500));
            }
          }
          await audit("sandbox.run", "sandbox_run", run.id, summary, String(payload.reason ?? ""));
          return json({
            ok: true,
            data: {
              run_id: run.id,
              summary,
              changes: results
                .sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta))
                .slice(0, 100),
            },
          });
        } catch (error) {
          await admin
            .from("sandbox_runs")
            .update({
              status: "failed",
              error: mapError(error as any),
              finished_at: new Date().toISOString(),
            })
            .eq("id", run.id);
          throw error;
        }
      }

      case "sandbox.list": {
        const { data, error } = await admin
          .from("sandbox_runs")
          .select(
            "id,actor_id,sample_size,baseline_revision,candidate_config,status,summary,started_at,finished_at,error",
          )
          .order("started_at", { ascending: false })
          .limit(25);
        if (error) throw error;
        return json({ ok: true, data: data ?? [] });
      }

      case "sandbox.get": {
        const id = String(payload.id ?? "");
        if (!id) return json({ error: "Run id is required" }, 400);
        const [{ data: run }, { data: results }] = await Promise.all([
          admin.from("sandbox_runs").select("*").eq("id", id).maybeSingle(),
          admin
            .from("sandbox_results")
            .select(
              "id,user_id,as_role,candidate_id,baseline_rank,candidate_rank,baseline_score,candidate_score,delta",
            )
            .eq("run_id", id)
            .order("baseline_rank", { ascending: true })
            .limit(1000),
        ]);
        if (!run) return json({ error: "Run not found" }, 404);
        return json({ ok: true, data: { run, results: results ?? [] } });
      }

      case "audit.list": {
        const limit = clampInt(payload.limit, 100, 1, 500);
        let query = admin
          .from("admin_audit_log")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(limit);
        if (payload.filter_action) {
          query = query.eq("action", String(payload.filter_action));
        }
        if (payload.actor_id) query = query.eq("actor_id", String(payload.actor_id));
        const { data, error } = await query;
        if (error) throw error;
        return json({
          ok: true,
          data: (data ?? []).map((row: any) => ({
            ...row,
            reversible: isRevertible(row),
          })),
        });
      }

      case "audit.revert": {
        const id = Number(payload.id);
        const reason = String(payload.reason ?? "").trim();
        if (!Number.isFinite(id) || id <= 0) {
          return json({ error: "Audit id is required" }, 400);
        }
        if (!reason) return json({ error: "A reason is required" }, 400);

        const { data: original } = await admin
          .from("admin_audit_log")
          .select("*")
          .eq("id", id)
          .maybeSingle();
        if (!original) return json({ error: "Audit entry not found" }, 404);
        if (original.reverted_at) {
          return json({ error: "This action was already reverted" }, 409);
        }
        if (!isRevertible(original)) {
          return json({ error: "This action cannot be reverted" }, 400);
        }
        // Reverting an access change re-grants or removes admin rows, so it
        // needs the same owner-only rule as admins.add/update/remove.
        if (
          ["admin.add", "admin.update", "admin.remove"].includes(
            original.action,
          ) &&
          adminRow.role !== "owner"
        ) {
          return json(
            { error: "Only an owner can revert admin access changes" },
            403,
          );
        }

        const detail = original.detail ?? {};
        let result: any = {};

        try {
          switch (original.action) {
            case "report.resolve": {
              const reportBefore = detail.before?.report;
              if (!reportBefore) throw new Error("No report snapshot");
              const { error } = await admin
                .from("reports")
                .update({
                  status: reportBefore.status,
                  resolution: reportBefore.resolution,
                  assigned_to: reportBefore.assigned_to,
                  resolved_at: reportBefore.resolved_at,
                  action_taken: reportBefore.action_taken,
                  action_by: reportBefore.action_by,
                  action_at: reportBefore.action_at,
                })
                .eq("id", original.target_id);
              if (error) throw error;

              const userId = reportBefore.reported_id;
              const userBefore = detail.before?.user;
              const wasWarn = reportBefore.action_taken === "warn";
              if (userId && wasWarn) {
                const { data: activeWarning } = await admin
                  .from("account_warnings")
                  .select("id")
                  .eq("report_id", original.target_id)
                  .is("revoked_at", null)
                  .maybeSingle();
                if (activeWarning?.id) {
                  const { error: revokeError } = await admin.rpc("admin_revoke_warning", {
                    p_warning: activeWarning.id,
                    p_actor: user.id,
                    p_reason: `Revert audit #${id}: ${reason}`,
                  });
                  if (revokeError) throw revokeError;
                }
              }
              if (userId && userBefore?.profile) {
                const restore: Record<string, unknown> = {
                  moderation_status: userBefore.profile.moderation_status,
                  suspended_at: userBefore.profile.suspended_at,
                };
                // The warning counter is derived from account_warnings. For a
                // revoke, the trigger already restored it.
                if (!wasWarn) {
                  restore.warning_count = userBefore.profile.warning_count;
                  restore.last_warned_at = userBefore.profile.last_warned_at;
                }
                const { error: profileError } = await admin
                  .from("profiles")
                  .update(restore)
                  .eq("id", userId);
                if (profileError) throw profileError;
                const stillBanned =
                  userBefore.banned_until &&
                  new Date(userBefore.banned_until).getTime() > Date.now();
                await admin.auth.admin.updateUserById(userId, {
                  ban_duration: stillBanned ? "876000h" : "none",
                });
                await admin.from("match_cache").delete().or(`user_id.eq.${userId},candidate_id.eq.${userId}`);
              }
              result = { report_id: original.target_id, restored: true };
              break;
            }

            case "user.ban":
            case "user.unban": {
              const before = detail.before;
              if (!before?.profile) throw new Error("No user snapshot");
              const userId = original.target_id;
              const { error } = await admin
                .from("profiles")
                .update({
                  moderation_status: before.profile.moderation_status,
                  suspended_at: before.profile.suspended_at,
                  warning_count: before.profile.warning_count,
                  last_warned_at: before.profile.last_warned_at,
                })
                .eq("id", userId);
              if (error) throw error;
              const wasBanned =
                before.banned_until &&
                new Date(before.banned_until).getTime() > Date.now();
              await admin.auth.admin.updateUserById(userId, {
                ban_duration: wasBanned ? "876000h" : "none",
              });
              await admin.from("match_cache").delete().or(`user_id.eq.${userId},candidate_id.eq.${userId}`);
              result = { user_id: userId, restored: true };
              break;
            }

            case "skill.update":
            case "skill.approve":
            case "skill.reject":
            case "skill.retire": {
              const before = detail.before;
              if (!before?.id) throw new Error("No skill snapshot");
              const { data: current } = await admin
                .from("skill_nodes")
                .select("*")
                .eq("id", before.id)
                .maybeSingle();
              if (!current) throw new Error("Skill not found");
              if (before.name && before.name !== current.name) {
                const { error } = await admin.rpc("admin_rename_skill", {
                  p_node: before.id,
                  p_name: before.name,
                  p_actor: user.id,
                  p_reason: `Revert audit #${id}: ${reason}`,
                });
                if (error) throw error;
              }
              const { error } = await admin
                .from("skill_nodes")
                .update({
                  status: before.status,
                  is_visible: before.is_visible,
                  is_general: before.is_general,
                  approval_source: before.approval_source,
                  auto_approved: before.auto_approved,
                  updated_at: new Date().toISOString(),
                })
                .eq("id", before.id);
              if (error) throw error;
              await admin.from("match_cache").delete().gte("rank", 0);
              result = { node_id: before.id, restored: true };
              break;
            }

            case "skill.move": {
              const before = detail.before;
              if (!before?.id) throw new Error("No skill snapshot");
              const { data, error } = await admin.rpc("admin_move_skill", {
                p_node: before.id,
                p_new_parent: before.parent_id ?? null,
                p_actor: user.id,
                p_reason: `Revert audit #${id}: ${reason}`,
              });
              if (error) throw error;
              await admin.from("match_cache").delete().gte("rank", 0);
              result = data;
              break;
            }

            case "skill.create": {
              const nodeId = detail.after?.id ?? original.target_id;
              if (!nodeId) throw new Error("No created node id");
              const { error } = await admin
                .from("skill_nodes")
                .update({ status: "retired", is_visible: false, updated_at: new Date().toISOString() })
                .eq("id", nodeId);
              if (error) throw error;
              await admin.from("match_cache").delete().gte("rank", 0);
              result = { node_id: nodeId, retired: true };
              break;
            }

            case "skill.import": {
              const nodeIds: string[] = detail.node_ids ?? [];
              if (nodeIds.length === 0) throw new Error("No imported node ids");
              const { error } = await admin
                .from("skill_nodes")
                .update({ status: "retired", is_visible: false, updated_at: new Date().toISOString() })
                .in("id", nodeIds);
              if (error) throw error;
              await admin.from("match_cache").delete().gte("rank", 0);
              result = { retired: nodeIds.length };
              break;
            }

            case "config.publish":
            case "config.rollback": {
              const beforeConfig = detail.before_config;
              if (!beforeConfig || typeof beforeConfig !== "object") {
                throw new Error("No config snapshot");
              }
              const { data: published, error } = await admin.rpc("admin_publish_config", {
                p_config: beforeConfig,
                p_actor: user.id,
                p_reason: `Revert audit #${id}: ${reason}`,
                p_label: `Revert audit #${id}`,
                p_version_id: null,
              });
              if (error) throw error;
              await admin.from("match_cache").delete().gte("rank", 0);
              result = published;
              break;
            }

            case "admin.add": {
              const targetId = detail.target_id ?? original.target_id;
              if (!targetId) throw new Error("No admin target");
              if (targetId === user.id) throw new Error("You cannot revert your own access grant");
              if (detail.before?.user_id) {
                const { error } = await admin.from("admin_users").upsert({
                  user_id: detail.before.user_id,
                  role: detail.before.role,
                  status: detail.before.status,
                  mfa_required: detail.before.mfa_required,
                  created_by: detail.before.created_by,
                });
                if (error) throw error;
                result = { user_id: targetId, restored: true };
              } else {
                const { data: current } = await admin
                  .from("admin_users")
                  .select("*")
                  .eq("user_id", targetId)
                  .maybeSingle();
                if (current?.role === "owner" && (await activeOwnerCount(admin)) <= 1) {
                  throw new Error("Cannot remove the last active owner");
                }
                const { error } = await admin.from("admin_users").delete().eq("user_id", targetId);
                if (error) throw error;
                result = { user_id: targetId, removed: true };
              }
              break;
            }

            case "admin.update": {
              const before = detail.before;
              if (!before?.user_id) throw new Error("No admin snapshot");
              const { data: current } = await admin
                .from("admin_users")
                .select("*")
                .eq("user_id", before.user_id)
                .maybeSingle();
              if (!current) throw new Error("Admin row not found");
              if (
                current.role === "owner" &&
                before.role !== "owner" &&
                (await activeOwnerCount(admin)) <= 1
              ) {
                throw new Error("Cannot remove the last active owner");
              }
              const { error } = await admin
                .from("admin_users")
                .update({
                  role: before.role,
                  status: before.status,
                  mfa_required: before.mfa_required,
                })
                .eq("user_id", before.user_id);
              if (error) throw error;
              result = { user_id: before.user_id, restored: true };
              break;
            }

            case "admin.remove": {
              const before = detail.before;
              if (!before?.user_id) throw new Error("No admin snapshot");
              const { error } = await admin.from("admin_users").upsert({
                user_id: before.user_id,
                role: before.role,
                status: before.status,
                mfa_required: before.mfa_required,
                created_by: before.created_by,
              });
              if (error) throw error;
              result = { user_id: before.user_id, restored: true };
              break;
            }

            default:
              throw new Error("This action cannot be reverted");
          }
        } catch (error) {
          return json({ error: mapError(error as any) }, 409);
        }

        const { data: revertRow, error: revertError } = await admin
          .from("admin_audit_log")
          .insert({
            actor_id: user.id,
            actor_email: user.email,
            action: "audit.revert",
            target_type: original.target_type,
            target_id: original.target_id,
            detail: {
              original_id: id,
              original_action: original.action,
              result,
            },
            reason,
            ip: ip || null,
            user_agent: userAgent || null,
          })
          .select("id")
          .single();
        if (revertError) throw revertError;

        const { error: markError } = await admin
          .from("admin_audit_log")
          .update({
            reverted_at: new Date().toISOString(),
            reverted_by: user.id,
            revert_audit_id: revertRow.id,
          })
          .eq("id", id);
        if (markError) throw markError;

        return json({
          ok: true,
          data: { original_id: id, revert_audit_id: revertRow.id, result },
        });
      }

      case "backups.create": {
        const requested = Array.isArray(payload.scope) ? payload.scope : [];
        const scope = requested.length
          ? requested.map(String).filter((s) => BACKUP_GROUPS[s])
          : ["core", "moderation", "matching", "admin"];
        if (scope.length === 0) return json({ error: "Invalid backup scope" }, 400);
        const tableSet = new Set(scope.flatMap((group) => BACKUP_GROUPS[group] ?? []));
        const label = String(payload.label ?? "").trim() || `Manual backup ${new Date().toISOString()}`;
        const days = clampInt(payload.days, 30, 1, 365);
        const expiresAt = new Date(Date.now() + days * 86400000).toISOString();

        const { data: backup, error: createError } = await admin
          .from("admin_backups")
          .insert({
            label,
            scope,
            status: "running",
            created_by: user.id,
            expires_at: expiresAt,
          })
          .select("*")
          .single();
        if (createError) throw createError;

        try {
          const tables: Record<string, any[]> = {};
          const counts: Record<string, number> = {};
          const truncated: Record<string, boolean> = {};
          let totalRows = 0;
          for (const table of tableSet) {
            const result = await selectAllRows(admin, table);
            tables[table] = result.rows;
            counts[table] = result.rows.length;
            if (result.truncated) truncated[table] = true;
            totalRows += result.rows.length;
          }

          const document = {
            format: "palturo-admin-backup-v1",
            project_ref: "yjcrfgvenilptrnudvcb",
            created_at: new Date().toISOString(),
            scope,
            counts,
            truncated,
            tables,
          };
          const serialized = JSON.stringify(document);
          const bytes = new TextEncoder().encode(serialized);
          const checksum = await sha256Hex(bytes);
          const storagePath = `${backup.id}.json`;
          const { error: uploadError } = await admin.storage
            .from(BACKUP_BUCKET)
            .upload(storagePath, new Blob([serialized], { type: "application/json" }), {
              contentType: "application/json",
              upsert: true,
            });
          if (uploadError) throw uploadError;

          const { data: done, error: updateError } = await admin
            .from("admin_backups")
            .update({
              status: "complete",
              storage_path: storagePath,
              size_bytes: bytes.byteLength,
              checksum,
              table_counts: counts,
              total_rows: totalRows,
              completed_at: new Date().toISOString(),
            })
            .eq("id", backup.id)
            .select("*")
            .single();
          if (updateError) throw updateError;

          await audit(
            "backup.create",
            "admin_backup",
            backup.id,
            { scope, total_rows: totalRows, size_bytes: bytes.byteLength, checksum },
            label,
          );
          return json({ ok: true, data: done });
        } catch (error) {
          await admin
            .from("admin_backups")
            .update({
              status: "failed",
              error: mapError(error as any),
              completed_at: new Date().toISOString(),
            })
            .eq("id", backup.id);
          throw error;
        }
      }

      case "backups.list": {
        const { data, error } = await admin
          .from("admin_backups")
          .select("*")
          .neq("status", "deleted")
          .order("created_at", { ascending: false })
          .limit(100);
        if (error) throw error;
        return json({
          ok: true,
          data: (data ?? []).map((row: any) => ({
            ...row,
            downloadable: row.status === "complete" && Boolean(row.storage_path),
          })),
        });
      }

      case "backups.download": {
        const id = String(payload.id ?? "");
        if (!id) return json({ error: "Backup id is required" }, 400);
        const { data: row, error } = await admin
          .from("admin_backups")
          .select("id,storage_path,status")
          .eq("id", id)
          .maybeSingle();
        if (error) throw error;
        if (!row?.storage_path || row.status !== "complete") {
          return json({ error: "Backup is not downloadable" }, 404);
        }
        const { data: signed, error: signError } = await admin.storage
          .from(BACKUP_BUCKET)
          .createSignedUrl(row.storage_path, 3600);
        if (signError) throw signError;
        await audit("backup.download", "admin_backup", id, null, "Signed download link");
        return json({ ok: true, data: { url: signed.signedUrl, expires_in: 3600 } });
      }

      case "backups.verify": {
        const id = String(payload.id ?? "");
        if (!id) return json({ error: "Backup id is required" }, 400);
        const { data: row, error } = await admin
          .from("admin_backups")
          .select("*")
          .eq("id", id)
          .maybeSingle();
        if (error) throw error;
        if (!row) return json({ error: "Backup not found" }, 404);
        if (!row.storage_path) return json({ ok: true, data: { exists: false } });
        const filename = String(row.storage_path).split("/").pop() ?? "";
        const folder = String(row.storage_path).includes("/")
          ? String(row.storage_path).slice(0, String(row.storage_path).lastIndexOf("/"))
          : "";
        const { data: objects, error: listError } = await admin.storage
          .from(BACKUP_BUCKET)
          .list(folder, { search: filename, limit: 10 });
        if (listError) throw listError;
        const found = (objects ?? []).find((object: any) => object.name === filename);
        const sizeMatch = found ? Number(found.metadata?.size ?? 0) === Number(row.size_bytes) : false;
        return json({
          ok: true,
          data: {
            exists: Boolean(found),
            size_match: sizeMatch,
            storage_size: found?.metadata?.size ?? null,
            recorded_size: row.size_bytes,
          },
        });
      }

      case "backups.delete": {
        const id = String(payload.id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Backup id and reason are required" }, 400);
        const { data: row } = await admin
          .from("admin_backups")
          .select("*")
          .eq("id", id)
          .maybeSingle();
        if (!row) return json({ error: "Backup not found" }, 404);
        if (row.storage_path) {
          await admin.storage.from(BACKUP_BUCKET).remove([row.storage_path]);
        }
        const { error } = await admin
          .from("admin_backups")
          .update({ status: "deleted", storage_path: null, error: reason })
          .eq("id", id);
        if (error) throw error;
        await audit("backup.delete", "admin_backup", id, { label: row.label }, reason);
        return json({ ok: true });
      }

      case "backups.prune": {
        const now = new Date().toISOString();
        const { data: expired, error } = await admin
          .from("admin_backups")
          .select("id,storage_path,label")
          .eq("status", "complete")
          .lt("expires_at", now)
          .limit(100);
        if (error) throw error;
        let removed = 0;
        for (const row of expired ?? []) {
          if (row.storage_path) {
            await admin.storage.from(BACKUP_BUCKET).remove([row.storage_path]);
          }
          await admin
            .from("admin_backups")
            .update({ status: "deleted", storage_path: null, error: "Expired" })
            .eq("id", row.id);
          removed++;
        }
        if (removed > 0) {
          await audit("backup.prune", "admin_backup", null, { removed });
        }
        return json({ ok: true, data: { removed } });
      }

      case "exports.log": {
        const surface = String(payload.surface ?? "unknown");
        const format = payload.format === "json" ? "json" : "csv";
        const rowCount = clampInt(payload.row_count, 0, 0, 1000000);
        const { data, error } = await admin
          .from("admin_exports")
          .insert({ actor_id: user.id, surface, format, row_count: rowCount })
          .select("id,created_at")
          .single();
        if (error) throw error;
        await audit("export", surface, data.id, { format, row_count: rowCount });
        return json({ ok: true, data });
      }

      case "savedViews.list": {
        const surface = String(payload.surface ?? "");
        let query = admin
          .from("admin_saved_views")
          .select("*")
          .order("created_at", { ascending: false });
        if (surface) query = query.eq("surface", surface);
        const { data, error } = await query;
        if (error) throw error;
        return json({
          ok: true,
          data: (data ?? []).filter(
            (v: any) => v.shared || v.owner_id === user.id || adminRow.role === "owner",
          ),
        });
      }

      case "savedViews.save": {
        const surface = String(payload.surface ?? "analytics");
        const name = String(payload.name ?? "").trim();
        const config = payload.config;
        if (!name || !config || typeof config !== "object") {
          return json({ error: "Name and config are required" }, 400);
        }
        const { data, error } = await admin
          .from("admin_saved_views")
          .insert({
            owner_id: user.id,
            surface,
            name,
            config,
            shared: payload.shared === true,
          })
          .select("*")
          .single();
        if (error) throw error;
        return json({ ok: true, data });
      }

      case "savedViews.delete": {
        const id = String(payload.id ?? "");
        if (!id) return json({ error: "View id is required" }, 400);
        const { data: view } = await admin
          .from("admin_saved_views")
          .select("id,owner_id")
          .eq("id", id)
          .maybeSingle();
        if (!view) return json({ error: "View not found" }, 404);
        if (view.owner_id !== user.id && adminRow.role !== "owner") {
          return json({ error: "Only the owner can delete this view" }, 403);
        }
        const { error } = await admin.from("admin_saved_views").delete().eq("id", id);
        if (error) throw error;
        return json({ ok: true });
      }

      case "admins.list": {
        const { data, error } = await admin
          .from("admin_users")
          .select("*")
          .order("created_at");
        if (error) throw error;
        const ids = (data ?? []).map((row: any) => row.user_id);
        const { data: profiles } = ids.length
          ? await admin
              .from("profiles")
              .select("id,display_name,email")
              .in("id", ids)
          : { data: [] as any[] };
        const byId = new Map(
          (profiles ?? []).map((p: any) => [p.id, p]),
        );
        return json({
          ok: true,
          data: (data ?? []).map((row: any) => ({
            ...row,
            profile: byId.get(row.user_id) ?? null,
          })),
        });
      }

      case "admins.add": {
        if (adminRow.role !== "owner") return json({ error: "Owner only" }, 403);
        const userId = String(payload.user_id ?? "");
        const email = String(payload.email ?? "").trim();
        const role = String(payload.role ?? "analyst");
        const mfaRequired = role === "owner" ? true : payload.mfa_required !== false;
        if (!["owner", "admin", "analyst", "moderator", "support"].includes(role)) {
          return json({ error: "Invalid role" }, 400);
        }
        let targetId = userId;
        if (!targetId && email) {
          const { data: profile } = await admin
            .from("profiles")
            .select("id")
            .eq("email", email)
            .maybeSingle();
          targetId = profile?.id ?? "";
        }
        if (!targetId) return json({ error: "User not found" }, 404);
        const { data: before } = await admin
          .from("admin_users")
          .select("*")
          .eq("user_id", targetId)
          .maybeSingle();
        const { error } = await admin.from("admin_users").upsert({
          user_id: targetId,
          role,
          status: "active",
          mfa_required: mfaRequired,
          created_by: user.id,
        });
        if (error) throw error;
        await audit("admin.add", "admin_user", targetId, {
          target_id: targetId,
          before,
          role,
          mfa_required: mfaRequired,
        });
        return json({ ok: true });
      }

      case "admins.update": {
        if (adminRow.role !== "owner") return json({ error: "Owner only" }, 403);
        const targetId = String(payload.user_id ?? "");
        if (!targetId) return json({ error: "User id is required" }, 400);
        const updates: Record<string, any> = {};
        for (const key of ["role", "status", "mfa_required"]) {
          if (payload[key] !== undefined) updates[key] = payload[key];
        }
        if (Object.keys(updates).length === 0) return json({ error: "No fields" }, 400);
        if (
          updates.role !== undefined &&
          !["owner", "admin", "analyst", "moderator", "support"].includes(updates.role)
        ) {
          return json({ error: "Invalid role" }, 400);
        }
        if (
          updates.status !== undefined &&
          !["active", "disabled"].includes(updates.status)
        ) {
          return json({ error: "Invalid status" }, 400);
        }
        const { data: current } = await admin
          .from("admin_users")
          .select("*")
          .eq("user_id", targetId)
          .maybeSingle();
        if (!current) return json({ error: "Admin not found" }, 404);
        if (current.role === "owner" && updates.role && updates.role !== "owner") {
          const { count } = await admin
            .from("admin_users")
            .select("*", { count: "exact", head: true })
            .eq("role", "owner")
            .eq("status", "active");
          if ((count ?? 0) <= 1) return json({ error: "Cannot remove the last owner" }, 409);
        }
        if (current.role === "owner" && updates.status === "disabled") {
          const { count } = await admin
            .from("admin_users")
            .select("*", { count: "exact", head: true })
            .eq("role", "owner")
            .eq("status", "active");
          if ((count ?? 0) <= 1) {
            return json({ error: "Cannot disable the last active owner" }, 409);
          }
        }
        if (targetId === user.id && updates.status === "disabled") {
          return json({ error: "You cannot disable your own admin account" }, 409);
        }
        if (
          updates.mfa_required === false &&
          (current.role === "owner" || updates.role === "owner")
        ) {
          return json({ error: "Owner accounts must keep MFA enabled" }, 409);
        }
        const { error } = await admin.from("admin_users").update(updates).eq("user_id", targetId);
        if (error) throw error;
        await audit("admin.update", "admin_user", targetId, { before: current, updates });
        return json({ ok: true });
      }

      case "admins.remove": {
        if (adminRow.role !== "owner") return json({ error: "Owner only" }, 403);
        const targetId = String(payload.user_id ?? "");
        if (!targetId) return json({ error: "User id is required" }, 400);
        if (targetId === user.id) return json({ error: "You cannot remove yourself" }, 409);
        const { data: current } = await admin
          .from("admin_users")
          .select("*")
          .eq("user_id", targetId)
          .maybeSingle();
        if (!current) return json({ error: "Admin not found" }, 404);
        if (current.role === "owner") {
          const { count } = await admin
            .from("admin_users")
            .select("*", { count: "exact", head: true })
            .eq("role", "owner")
            .eq("status", "active");
          if ((count ?? 0) <= 1) return json({ error: "Cannot remove the last owner" }, 409);
        }
        const { error } = await admin.from("admin_users").delete().eq("user_id", targetId);
        if (error) throw error;
        await audit("admin.remove", "admin_user", targetId, { before: current });
        return json({ ok: true });
      }

      default:
        return json({ error: "Unknown action" }, 400);
    }
  } catch (error) {
    console.error(`[admin-api] ${action}: ${(error as Error)?.message ?? error}`);
    return json({ error: mapError(error as any) }, 500);
  }
});
