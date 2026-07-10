# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# IMPERSONATE_BACKEND (additive) — explicit "enter tenant" for platform_owner.
#   * getSessionUser reads user_sessions.metadata.active_tenant_id -> session.tenantId
#   * requireModuleAccess passes the entered tenant through (instead of forcing null)
#   * /api/platform/me returns activeTenantId/name (for the banner)
#   * new POST /api/platform/enter-tenant + /exit-tenant (platform_owner, audited)
# Fully additive: when no tenant is entered, tenantId stays null => existing
# fallbacks behave exactly as before. Removing the fallbacks happens LATER.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) add us.metadata to the getSessionUser SELECT
rep(
"""       us.id as session_id,
       us.user_id,
       us.expires_at,
       u.email,""",
"""       us.id as session_id,
       us.user_id,
       us.expires_at,
       us.metadata,
       u.email,""",
    "select-metadata")

# 2) getSessionUser return: inject impersonated tenant for platform_owner
rep(
"""  return {
    sessionId: row.session_id,
    userId: row.user_id,
    email: row.email,
    name: row.name || row.full_name || "",
    role: normalizeRole(row.assignment_role || row.project_role || row.organization_role || row.role),
    organizationId: row.organization_id,
    projectId: row.company_id || row.assessment_project_id
  };""",
"""  const _role = normalizeRole(row.assignment_role || row.project_role || row.organization_role || row.role);
  const _sess = {
    sessionId: row.session_id,
    userId: row.user_id,
    email: row.email,
    name: row.name || row.full_name || "",
    role: _role,
    organizationId: row.organization_id,
    projectId: row.company_id || row.assessment_project_id
  };
  if (_role === "platform_owner") {
    const _meta = (row.metadata && typeof row.metadata === "object") ? row.metadata : {};
    _sess.tenantId = _meta.active_tenant_id || null;
    _sess.impersonating = !!_meta.active_tenant_id;
  }
  return _sess;""",
    "getsession-inject")

# 3) requireModuleAccess platform_owner branch: honor the entered tenant
rep(
"""    if (!_pOwnerHasTenant.rowCount) {
      return { ...session, tenantId: null, tenantName: null, tenantRole: "platform_owner",
               moduleRole: "admin", plan: "internal", features: {}, permissions: {} };
    }""",
"""    if (!_pOwnerHasTenant.rowCount) {
      let _tName = null;
      if (session.tenantId) {
        const _tn = await query("SELECT name FROM platform_tenants WHERE id=$1 AND status='active'", [session.tenantId]);
        _tName = _tn.rows[0] ? _tn.rows[0].name : null;
        if (!_tName) session.tenantId = null;
      }
      return { ...session, tenantId: session.tenantId || null, tenantName: _tName, tenantRole: "platform_owner",
               moduleRole: "admin", plan: "internal", features: {}, permissions: {} };
    }""",
    "modaccess-passthrough")

# 4) /api/platform/me: expose activeTenant for the banner
rep(
"""    if (normalizeRole(session.role) === "platform_owner") {
      sendJson(response, 200, {
        userId: session.userId, name: session.name, globalRole: "platform_owner",
        tenantId: null, tenantName: null, tenantRole: "platform_owner",
        subscriptions: []
      });
      return;
    }""",
"""    if (normalizeRole(session.role) === "platform_owner") {
      let _atName = null;
      if (session.tenantId) {
        const _t = await query("SELECT name FROM platform_tenants WHERE id=$1 AND status='active'", [session.tenantId]);
        _atName = _t.rows[0] ? _t.rows[0].name : null;
      }
      sendJson(response, 200, {
        userId: session.userId, name: session.name, globalRole: "platform_owner",
        tenantId: session.tenantId || null, tenantName: _atName, tenantRole: "platform_owner",
        activeTenantId: session.tenantId || null, activeTenantName: _atName,
        subscriptions: []
      });
      return;
    }""",
    "platform-me-active")

# 5) enter/exit endpoints, inserted before the tenants list route
rep(
"""// GET /api/platform/tenants (platform_owner only)
if (request.method === "GET" && url.pathname === "/api/platform/tenants") {""",
"""if (request.method === "POST" && url.pathname === "/api/platform/enter-tenant") {
  const session = await requirePlatformOwner(request, response);
  if (!session) return;
  try {
    const _b = await readJson(request);
    const _tid = _b && _b.tenantId;
    if (!_tid) { sendJson(response, 400, { error: "tenantId gerekli" }); return; }
    const _t = await query("SELECT id, name FROM platform_tenants WHERE id=$1 AND status='active'", [_tid]);
    if (!_t.rowCount) { sendJson(response, 404, { error: "Tenant bulunamadi." }); return; }
    await query("UPDATE user_sessions SET metadata = jsonb_set(COALESCE(metadata,'{}'::jsonb), '{active_tenant_id}', to_jsonb($1::text)) WHERE id=$2", [_tid, session.sessionId]);
    try { await query("INSERT INTO krb_audit_logs (actor_user_id, actor_email, action, entity_type, entity_id) VALUES ($1,$2,'enter_tenant','tenant',$3)", [session.userId, session.email, _tid]); } catch (e) {}
    sendJson(response, 200, { ok: true, tenant: { id: _t.rows[0].id, name: _t.rows[0].name } });
  } catch (e) { sendJson(response, 500, { error: String((e && e.message) || e) }); }
  return;
}
if (request.method === "POST" && url.pathname === "/api/platform/exit-tenant") {
  const session = await requirePlatformOwner(request, response);
  if (!session) return;
  try {
    await query("UPDATE user_sessions SET metadata = (COALESCE(metadata,'{}'::jsonb) - 'active_tenant_id') WHERE id=$1", [session.sessionId]);
    try { await query("INSERT INTO krb_audit_logs (actor_user_id, actor_email, action, entity_type) VALUES ($1,$2,'exit_tenant','tenant')", [session.userId, session.email]); } catch (e) {}
    sendJson(response, 200, { ok: true });
  } catch (e) { sendJson(response, 500, { error: String((e && e.message) || e) }); }
  return;
}
// GET /api/platform/tenants (platform_owner only)
if (request.method === "GET" && url.pathname === "/api/platform/tenants") {""",
    "enter-exit-endpoints")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
