// PalTuro Admin API
// Server-side admin surface. The browser never receives a service-role key;
// every action verifies the caller's admin row, role, and MFA level here.

import { createClient } from "jsr:@supabase/supabase-js@2";

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
    "config.read", "config.write", "sandbox.run", "audit.read",
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
  "moderation.reports": "moderation.read",
  "moderation.resolveReport": "moderation.write",
  "moderation.skills": "moderation.read",
  "moderation.skillAction": "moderation.write",
  "moderation.notes": "moderation.read",
  "moderation.noteAction": "moderation.write",
  "skills.list": "skills.read",
  "skills.update": "skills.write",
  "skills.create": "skills.write",
  "skills.merge": "skills.write",
  "skills.import": "skills.write",
  "config.get": "config.read",
  "config.saveDraft": "config.write",
  "config.publish": "config.write",
  "config.rollback": "config.write",
  "sandbox.run": "sandbox.run",
  "sandbox.list": "sandbox.run",
  "sandbox.get": "sandbox.run",
  "audit.list": "audit.read",
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

      case "analytics": {
        const surface = String(payload.surface ?? "growth");
        const days = clampInt(payload.days, 30, 1, 365);
        const rpc =
          surface === "growth" ? "admin_growth"
          : surface === "supply" ? "admin_supply"
          : surface === "matching" ? "admin_matching"
          : surface === "conversations" ? "admin_conversations"
          : surface === "safety" ? "admin_safety"
          : surface === "system" ? "admin_system"
          : "";
        if (!rpc) return json({ error: "Unknown analytics surface" }, 400);
        const args =
          surface === "growth" || surface === "conversations" ? { p_days: days } : {};
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
        const [{ data: profile }, { data: skills }, { data: reports }, { data: auditRows }, { data: authUser }] =
          await Promise.all([
            admin.from("profiles").select("*").eq("id", id).maybeSingle(),
            admin
              .from("user_skills")
              .select("kind,note,skill:skill_id(id,name,path,kind),focus:focus_skill_id(name)")
              .eq("user_id", id),
            admin
              .from("reports")
              .select("id,reporter_id,reported_id,reason,details,status,created_at,resolved_at,messages_snapshot")
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
        const ban = action === "users.ban";
        const { error: authMutation } = await admin.auth.admin.updateUserById(id, {
          ban_duration: ban ? "876000h" : "none",
        });
        if (authMutation) throw authMutation;
        const { error: profileMutation } = await admin
          .from("profiles")
          .update({
            moderation_status: ban ? "suspended" : "active",
            suspended_at: ban ? new Date().toISOString() : null,
          })
          .eq("id", id);
        if (profileMutation) throw profileMutation;
        await admin.from("match_cache").delete().or(`user_id.eq.${id},candidate_id.eq.${id}`);
        await audit(ban ? "user.ban" : "user.unban", "profile", id, null, reason);
        return json({ ok: true, data: { id, status: ban ? "suspended" : "active" } });
      }

      case "users.delete": {
        const id = String(payload.id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id) return json({ error: "User id is required" }, 400);
        if (!reason) return json({ error: "A reason is required" }, 400);
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
        const { error } = await admin.rpc("admin_clear_mfa", { p_user: id });
        if (error) throw error;
        await audit("user.reset_mfa", "profile", id, null, reason);
        return json({ ok: true, data: { id } });
      }

      case "moderation.reports": {
        const { data, error } = await admin
          .from("reports")
          .select(
            "id,reporter_id,reported_id,reason,details,status,created_at,resolved_at,assigned_to,messages_snapshot,reporter:reporter_id(id,display_name,email),reported:reported_id(id,display_name,email),assigned:assigned_to(id,display_name)",
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
        const resolution = String(payload.resolution ?? "").trim();
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Report id and reason are required" }, 400);
        if (!["open", "reviewed", "dismissed", "actioned"].includes(status)) {
          return json({ error: "Invalid report status" }, 400);
        }
        const { error } = await admin
          .from("reports")
          .update({
            status,
            resolution: resolution || null,
            assigned_to: user.id,
            resolved_at: status === "open" ? null : new Date().toISOString(),
          })
          .eq("id", id);
        if (error) throw error;
        await audit("report.resolve", "report", id, { status, resolution }, reason);
        return json({ ok: true });
      }

      case "moderation.skills": {
        const { data, error } = await admin
          .from("skill_nodes")
          .select(
            "id,name,path,kind,status,origin,auto_approved,is_visible,created_at,parent:parent_id(id,name,path,kind),submitted:submitted_by(id,display_name)",
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
        const { error } = await admin
          .from("skill_nodes")
          .update({
            status,
            is_visible: decision === "approve",
            updated_at: new Date().toISOString(),
          })
          .eq("id", id);
        if (error) throw error;
        await admin.from("skill_change_log").insert({
          node_id: id,
          action: decision,
          before,
          after: { status, is_visible: decision === "approve" },
          reason,
          actor_id: user.id,
        });
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit(`skill.${decision}`, "skill_node", id, { status }, reason);
        return json({ ok: true });
      }

      case "moderation.notes": {
        const status = String(payload.status ?? "pending");
        let query = admin
          .from("note_moderation_queue")
          .select(
            "id,user_id,kind,name,skill_id,note,status,attempts,last_error,created_at,updated_at,user:user_id(id,display_name,email),skill:skill_id(id,name,path)",
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
          .update({ status, updated_at: new Date().toISOString() })
          .eq("id", id);
        if (error) throw error;
        await audit(`note.${decision}`, "note", id, { status, user_id: before.user_id }, reason);
        return json({ ok: true, data: { id, status } });
      }

      case "skills.list": {
        const { data, error } = await admin
          .from("skill_nodes")
          .select(
            "id,name,path,depth,kind,status,origin,auto_approved,is_visible,is_general,usage_count,created_at,parent:parent_id(id,name)",
          )
          .order("path")
          .limit(1000);
        if (error) throw error;
        return json({ ok: true, data: data ?? [] });
      }

      case "skills.update": {
        const id = String(payload.id ?? "");
        const reason = String(payload.reason ?? "").trim();
        if (!id || !reason) return json({ error: "Skill id and reason are required" }, 400);
        const allowed: Record<string, any> = {};
        for (const key of ["name", "status", "is_visible", "is_general"]) {
          if (payload[key] !== undefined) allowed[key] = payload[key];
        }
        if (Object.keys(allowed).length === 0) return json({ error: "No fields to update" }, 400);
        const { data: before } = await admin.from("skill_nodes").select("*").eq("id", id).maybeSingle();
        const { error } = await admin.from("skill_nodes").update(allowed).eq("id", id);
        if (error) return json({ error: error.message }, 409);
        await admin.from("skill_change_log").insert({
          node_id: id,
          action: "update",
          before,
          after: allowed,
          reason,
          actor_id: user.id,
        });
        await audit("skill.update", "skill_node", id, allowed, reason);
        return json({ ok: true });
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
          })
          .select("id,name,path,kind,status")
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
        await audit("skill.create", "skill_node", data.id, data, reason);
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
            })
            .select("id,name,path,kind,status")
            .single();
          if (error) { skipped++; continue; }
          inserted++;
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
        await audit("skill.import", "skill_nodes", null, { inserted, skipped }, reason);
        return json({ ok: true, data: { inserted, skipped } });
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
        return json({
          ok: true,
          data: {
            config: config ?? [],
            values,
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
        await admin.from("match_cache").delete().gte("rank", 0);
        await audit(
          action === "config.rollback" ? "config.rollback" : "config.publish",
          "pipeline_config",
          String(published?.revision ?? ""),
          { version_id: published?.version_id ?? versionId },
          reason,
        );
        return json({ ok: true, data: published });
      }

      case "sandbox.run": {
        const sampleSize = clampInt(payload.sample_size, 50, 1, 500);
        const candidateConfig = payload.candidate_config;
        if (!candidateConfig || typeof candidateConfig !== "object") {
          return json({ error: "Candidate config is required" }, 400);
        }
        const { data: currentConfig } = await admin
          .from("pipeline_config")
          .select("key,value");
        const baselineRevision = Number(
          (currentConfig ?? []).find((r: any) => r.key === "__revision")?.value ?? 0,
        );
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
          const { data: cache, error: cacheErr } = await admin
            .from("match_cache")
            .select("user_id,as_role,candidate_id,rank,bi_score,rerank_score_a,rerank_score_b,calibrated_score,pipeline_mode")
            .order("user_id")
            .limit(10000);
          if (cacheErr) throw cacheErr;

          const aWeight = Number(candidateConfig.rerank_a_weight ?? 0.6);
          const bWeight = Number(candidateConfig.rerank_b_weight ?? 0.4);
          const formula = String(candidateConfig.reciprocal_formula ?? "geometric_mean");
          const bLimit = clampInt(candidateConfig.rerank_b_limit, 10, 0, 500);
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

          const scoreOf = (row: any, aRank: number) => {
            const pa = row.rerank_score_a === null ? null : Number(row.rerank_score_a);
            let pb = row.rerank_score_b === null ? null : Number(row.rerank_score_b);
            if (aRank > bLimit) pb = null;
            if (pa !== null && pb !== null) {
              if (formula === "weighted_mean") {
                return (aWeight * pa + bWeight * pb) / Math.max(0.0001, aWeight + bWeight);
              }
              return Math.sqrt(Math.max(0, pa) * Math.max(0, pb));
            }
            if (pa !== null) return pa;
            return Math.max(Number(row.bi_score ?? 0), 0);
          };

          for (const [, rows] of selected) {
            users++;
            const aSorted = [...rows].sort(
              (a, b) => Number(b.rerank_score_a ?? -1) - Number(a.rerank_score_a ?? -1),
            );
            const aRank = new Map(aSorted.map((r, i) => [r.candidate_id, i + 1]));
            const baseline = new Map(rows.map((r) => [r.candidate_id, r]));
            const scored = aSorted.map((row) => ({
              ...row,
              candidate_score: scoreOf(row, aRank.get(row.candidate_id) ?? 999),
            }));
            scored.sort((a, b) => b.candidate_score - a.candidate_score);
            scored.forEach((row, index) => {
              const candidateRank = index + 1;
              const baselineRank = Number(row.rank);
              const baselineScore = Number(row.calibrated_score);
              const delta = Number((row.candidate_score - baselineScore).toFixed(6));
              candidates++;
              if (row.rerank_score_b === null) candidateAOnly++;
              scoreDeltaTotal += delta;
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
              const baseTop = baseline.get(row.candidate_id) && Number(baseline.get(row.candidate_id).rank) <= 10;
              const nextTop = candidateRank <= 10;
              if (baseTop && nextTop) top10Overlap++;
              if (!baseTop && nextTop) top10New++;
              if (baseTop && !nextTop) top10Dropped++;
            });
          }

          const summary = {
            users,
            candidates,
            changed,
            improved,
            worsened,
            top10_overlap: top10Overlap,
            top10_new: top10New,
            top10_dropped: top10Dropped,
            avg_score_delta: candidates ? scoreDeltaTotal / candidates : 0,
            a_only_share: candidates ? candidateAOnly / candidates : 0,
            formula,
            b_limit: bLimit,
            note: "Cached-score replay only; no re-embedding or NIM rerank was run.",
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
        return json({ ok: true, data: data ?? [] });
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
            (v: any) => v.shared || v.owner_id === user.id || can(adminRow.role, "admins.read"),
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
        const mfaRequired = payload.mfa_required !== false;
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
        const { error } = await admin.from("admin_users").upsert({
          user_id: targetId,
          role,
          status: "active",
          mfa_required: mfaRequired,
          created_by: user.id,
        });
        if (error) throw error;
        await audit("admin.add", "admin_user", targetId, { role, mfa_required: mfaRequired });
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
        const { error } = await admin.from("admin_users").update(updates).eq("user_id", targetId);
        if (error) throw error;
        await audit("admin.update", "admin_user", targetId, updates);
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
        await audit("admin.remove", "admin_user", targetId);
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
