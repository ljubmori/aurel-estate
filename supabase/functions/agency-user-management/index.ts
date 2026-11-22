import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PERMISSIONS = ["properties_read","properties_write","properties_delete","properties_publish","inquiries_read","inquiries_write","clients_read","clients_write","media_write","content_write","seo_write"] as const;
// Agency owners/admins and agents have predefined RLS roles; only supported
// collaborator overrides are configurable until corresponding RLS exists.
const ROLE_PERMISSIONS: Record<string, readonly string[]> = {
  owner: [],
  admin: [],
  agent: [],
  collaborator: ["properties_read","properties_write","properties_delete","inquiries_read","inquiries_write"],
};
function sanitizePermissions(role: string, input: unknown): Record<string, boolean> {
  const raw = input && typeof input === "object" && !Array.isArray(input) ? input as Record<string, unknown> : {};
  const allowed = new Set(ROLE_PERMISSIONS[role] ?? []);
  return Object.fromEntries(PERMISSIONS.map(key => [key, allowed.has(key) && raw[key] === true]));
}
function validScope(role: string, scope: string) {
  return ["own","assigned","all"].includes(scope) && (role === "owner" || role === "admin" || scope !== "all");
}

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return reply({ error: "Authentication required" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply({ error: "Server auth is not configured" }, 500);

  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerData.user) return reply({ error: "Invalid session" }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply({ error: "Invalid JSON body" }, 400); }

  const agencyId = String(body.agency_id ?? "");
  const action = String(body.action ?? "");
  const targetUserId = String(body.user_id ?? "");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(agencyId)) {
    return reply({ error: "Invalid agency" }, 400);
  }

  // Staff mark their invitation as accepted on their first authenticated visit.
  if (action === "accept_invitation") {
    const { data: member, error } = await admin.from("agency_members")
      .select("user_id,joined_at,is_active")
      .eq("agency_id", agencyId)
      .eq("user_id", callerData.user.id)
      .maybeSingle();
    if (error || !member || !member.is_active) return reply({ error: "No active invitation found" }, 403);
    if (!member.joined_at) {
      const { error: updateError } = await admin.from("agency_members")
        .update({ joined_at: new Date().toISOString() })
        .eq("agency_id", agencyId).eq("user_id", callerData.user.id);
      if (updateError) return reply({ error: updateError.message }, 400);
    }
    return reply({ success: true });
  }

  const { data: callerMembership, error: membershipError } = await admin
    .from("agency_members")
    .select("role,is_active")
    .eq("agency_id", agencyId)
    .eq("user_id", callerData.user.id)
    .maybeSingle();

  if (membershipError || !callerMembership?.is_active || callerMembership.role !== "owner") {
    return reply({ error: "Only an active agency owner can manage team accounts" }, 403);
  }

  const writeAudit = async (event: string, userId: string, oldValues: unknown, newValues: unknown) => {
    const { error } = await admin.from("audit_logs").insert({
      agency_id: agencyId,
      actor_user_id: callerData.user.id,
      action: event,
      entity_type: "agency_members",
      entity_id: userId,
      old_values: oldValues ?? null,
      new_values: newValues ?? null,
    });
    if (error) console.error("Membership audit insert failed", error.message);
  };

  if (action === "invite") {
    const email = String(body.email ?? "").trim().toLowerCase();
    const role = String(body.role ?? "agent");
    const displayName = String(body.display_name ?? "").trim().slice(0, 120);
    const dataScope = String(body.data_scope ?? "assigned");
    const canPublish = Boolean(body.can_publish ?? false);
    const allowedRoles = ["admin", "agent", "collaborator"];
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply({ error: "Enter a valid email address" }, 400);
    if (!allowedRoles.includes(role)) return reply({ error: "Invalid role" }, 400);
    if (!validScope(role, dataScope)) return reply({ error: "Invalid data scope for role" }, 400);

    const permissionsInput = body.permissions && typeof body.permissions === "object"
      ? body.permissions as Record<string, unknown> : {};
    const permissions = sanitizePermissions(role, permissionsInput);

    const appUrl = Deno.env.get("APP_URL");
    const inviteOptions: Record<string, unknown> = {
      data: displayName ? { display_name: displayName } : {},
    };
    if (appUrl) inviteOptions.redirectTo = `${appUrl.replace(/\/$/, "")}/account/recovery`;
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, inviteOptions);
    if (inviteError || !invited.user) return reply({ error: inviteError?.message ?? "Invitation could not be created" }, 400);

    const { error: insertError } = await admin.from("agency_members").insert({
      agency_id: agencyId,
      user_id: invited.user.id,
      email,
      display_name: displayName,
      role,
      permissions,
      data_scope: dataScope,
      is_active: true,
      can_publish: canPublish,
      invited_at: new Date().toISOString(),
      joined_at: null,
    });

    if (insertError) {
      // An invitation may reuse an existing Auth user. Never delete that account on a failed membership write.
      console.error("Invitation membership insert failed", insertError.message);
      return reply({ error: "Invitation could not be linked to this agency. Check membership or existing account." }, 409);
    }
    await writeAudit("invite", invited.user.id, null, { email, display_name: displayName, role, data_scope: dataScope, permissions, can_publish: canPublish });
    return reply({ success: true, user_id: invited.user.id });
  }

  if (!targetUserId || (targetUserId === callerData.user.id && action === "deactivate")) {
    return reply({ error: "Invalid target user" }, 400);
  }

  const { data: target, error: targetError } = await admin
    .from("agency_members")
    .select("user_id,role,is_active,data_scope,permissions,can_publish,email,display_name")
    .eq("agency_id", agencyId)
    .eq("user_id", targetUserId)
    .maybeSingle();
  if (targetError || !target) return reply({ error: "Team member not found" }, 404);

  if (action === "update") {
    const patch: Record<string, unknown> = {};
    if (body.role !== undefined) {
      const role = String(body.role);
      if (!["owner", "admin", "agent", "collaborator"].includes(role)) return reply({ error: "Invalid role" }, 400);
      patch.role = role;
    }
    if (body.data_scope !== undefined) {
      const scope = String(body.data_scope);
      if (!validScope(String(patch.role ?? target.role), scope)) return reply({ error: "Invalid data scope for role" }, 400);
      patch.data_scope = scope;
    }
    if (body.permissions !== undefined) {
      if (!body.permissions || typeof body.permissions !== "object") return reply({ error: "Invalid permissions" }, 400);
      const input = body.permissions as Record<string, unknown>;
      const keys = ["properties_read","properties_write","properties_delete","properties_publish","inquiries_read","inquiries_write","clients_read","clients_write","media_write","content_write","seo_write"];
      patch.permissions = sanitizePermissions(String(patch.role ?? target.role), input);
    }
    if (body.can_publish !== undefined) patch.can_publish = Boolean(body.can_publish);
    if (body.is_active !== undefined) {
      if (targetUserId === callerData.user.id && body.is_active === false) return reply({ error: "You cannot deactivate your own owner account" }, 400);
      patch.is_active = Boolean(body.is_active);
    }
    // Role transitions must not retain privileges that the new role cannot hold.
    const effectiveRole = String(patch.role ?? target.role);
    const effectiveScope = String(patch.data_scope ?? target.data_scope);
    if (!validScope(effectiveRole, effectiveScope)) {
      patch.data_scope = effectiveRole === "owner" || effectiveRole === "admin" ? "all" : "assigned";
    }
    if (patch.role !== undefined && patch.permissions === undefined) {
      patch.permissions = sanitizePermissions(effectiveRole, target.permissions);
    }
    if (effectiveRole === "agent" && patch.can_publish === undefined) {
      patch.can_publish = Boolean(target.can_publish);
    }
    if (Object.keys(patch).length === 0) return reply({ error: "No supported changes supplied" }, 400);
    const { error } = await admin.from("agency_members").update(patch)
      .eq("agency_id", agencyId).eq("user_id", targetUserId);
    if (error) return reply({ error: error.message }, 400);
    await writeAudit("permissions_updated", targetUserId, target, patch);
    return reply({ success: true });
  }

  if (action === "deactivate" || action === "reactivate") {
    const { error } = await admin.from("agency_members")
      .update({ is_active: action === "reactivate" })
      .eq("agency_id", agencyId).eq("user_id", targetUserId);
    if (error) return reply({ error: error.message }, 400);
    await writeAudit(action === "deactivate" ? "deactivated" : "reactivated", targetUserId, target, { is_active: action === "reactivate" });
    return reply({ success: true });
  }

  return reply({ error: "Unsupported action" }, 400);
});
