# -*- coding: utf-8 -*-
# INVITE_LIST_V1 — GET /api/tenant/invitations (bekleyen) + DELETE (.../:id iptal).
#   Davet Et panelindeki "Bekleyen Davetler" listesi + iptal butonu icin (bugun 404).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "INVITE_LIST_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCHOR = '// GET /api/tenant/usage\nif (request.method === "GET" && url.pathname === "/api/tenant/usage") {'

NEW = '''// GET /api/tenant/invitations — bekleyen davetler  /* INVITE_LIST_V1 */
if (request.method === "GET" && url.pathname === "/api/tenant/invitations") {
  try {
    const session = await requireTenantAdmin(request);
    if (!session.tenantId) { sendJson(response, 403, { error: "Tenant context required." }); return; }
    const result = await query(
      `SELECT id, invited_email, module_id, module_role, status, created_at, expires_at
         FROM user_invitations
        WHERE tenant_id = $1 AND status = 'pending' AND expires_at > now()
        ORDER BY created_at DESC`, [session.tenantId]);
    sendJson(response, 200, result.rows);
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}

// DELETE /api/tenant/invitations/:id — daveti iptal et  /* INVITE_LIST_V1 */
const _invCancel = url.pathname.match(/^\\/api\\/tenant\\/invitations\\/([^/]+)$/);
if (request.method === "DELETE" && _invCancel) {
  try {
    const session = await requireTenantAdmin(request);
    if (!session.tenantId) { sendJson(response, 403, { error: "Tenant context required." }); return; }
    const r = await query(
      `UPDATE user_invitations SET status = 'cancelled'
        WHERE id = $1 AND tenant_id = $2 AND status = 'pending' RETURNING id`,
      [_invCancel[1], session.tenantId]);
    if (!r.rowCount) throw Object.assign(new Error("Invitation not found."), { statusCode: 404 });
    sendJson(response, 200, { message: "Invitation cancelled." });
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}

'''

assert s.count(ANCHOR) == 1, "anchor bulunamadi (%d)" % s.count(ANCHOR)
s = s.replace(ANCHOR, NEW + ANCHOR, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] INVITE_LIST_V1")
