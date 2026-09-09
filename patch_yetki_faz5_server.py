# -*- coding: utf-8 -*-
# YETKI_FAZ5 (server) — Etkin-yetki DENETCI ucu (salt-oku): bir kisinin saha yetkisi NEREDEN geliyor.
#   GET /api/tenant/users/:id/yetki-kaynak -> { module_role, departments(etkin), personal_grant, personal_deny, scope,
#   bolumler:[{ad,ikon,caps}] }. Client provenance'i bundan hesaplar (bolum / kisisel-ekleme / kisisel-cikarma / rol).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ5" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCH = "// POST /api/tenant/users/invite"
assert s.count(ANCH) == 1, "invite anchor=%d" % s.count(ANCH)
EP = '''// YETKI_FAZ5 — etkin-yetki denetci: kisinin saha yetkisi nereden geliyor (bolum / kisisel-ekleme / kisisel-cikarma / rol)
{ const _yk = url.pathname.match(/^\\/api\\/tenant\\/users\\/([^/]+)\\/yetki-kaynak$/);
  if (_yk && request.method === "GET") {
    try {
      const session = await requireTenantAdmin(request); const tid = session.tenantId; const uid = _yk[1];
      if (!tid) { sendJson(response, 403, { error: "Tenant context required." }); return; }
      const ur = await query(`SELECT module_role, permissions_json FROM tenant_user_modules WHERE tenant_id::text=$1::text AND user_id=$2 AND module_id='saha'`, [tid, uid]);
      const row = ur.rows[0] || {}; const pj = row.permissions_json || {};
      const dr = await query(`SELECT d.ad, d.ikon, d.template_json FROM tenant_department d JOIN tenant_department_membership m ON m.department_id=d.id AND m.tenant_id=d.tenant_id WHERE d.tenant_id::text=$1::text AND m.user_id=$2 ORDER BY d.ad`, [tid, uid]);
      const bolumler = dr.rows.map(r => ({ ad: r.ad, ikon: r.ikon || "\\ud83c\\udff7\\ufe0f", caps: (r.template_json && Array.isArray(r.template_json.capabilities)) ? r.template_json.capabilities : [] }));
      sendJson(response, 200, {
        module_role: row.module_role || null,
        departments: Array.isArray(pj.departments) ? pj.departments : [],
        personal_grant: Array.isArray(pj.personal_grant) ? pj.personal_grant : [],
        personal_deny: Array.isArray(pj.personal_deny) ? pj.personal_deny : [],
        scope: pj.scope || null,
        bolumler
      });
    } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
    return;
  }
}

'''
s = s.replace(ANCH, EP + ANCH, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ5 (server) — GET /api/tenant/users/:id/yetki-kaynak (etkin-yetki denetci)")
