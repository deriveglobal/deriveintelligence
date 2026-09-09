# -*- coding: utf-8 -*-
# YETKI_FAZ5B (server) — yetki degisiklik GUNLUGU (denetim): _yetkiLog helper + 3 yazma-yoluna log (Kisiler PATCH /
#   Bolumler apply / uyelik) + GET /api/tenant/yetki-log (aktor/hedef/bolum isimleriyle). Tablo DDL deploy'da.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ5B" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) _yetkiLog helper — _recomputeSahaCaps'ten once (ayni scope, endpointlerden once tanimli)
HELP_ANCH = 'const _recomputeSahaCaps = async (tenantId, userId) => {'
assert s.count(HELP_ANCH) == 1, "recompute anchor=%d" % s.count(HELP_ANCH)
HELP = '''/* YETKI_FAZ5B — yetki degisiklik gunlugu (denetim). Fire-and-forget; hata ana akisi bozmaz. */
const _yetkiLog = async (tenantId, actorId, eylem, opt) => {
  try {
    await query(`INSERT INTO tenant_yetki_log (tenant_id, actor_id, target_user_id, department_id, eylem, detay) VALUES ($1,$2,$3,$4,$5,$6::jsonb)`,
      [tenantId, actorId || null, (opt && opt.target) || null, (opt && opt.department) || null, eylem, JSON.stringify((opt && opt.detay) || {})]);
  } catch (e) { console.error("yetkiLog:", e && e.message); }
};
''' + HELP_ANCH
s = s.replace(HELP_ANCH, HELP, 1)

# 2) apply -> log
AP = '      sendJson(response, 200, { ok: true, uygulandi: _mem.length });'
assert s.count(AP) == 1, "apply sendJson anchor=%d" % s.count(AP)
s = s.replace(AP, '      await _yetkiLog(tid, session.userId, "bolum_uygula", { department: did, detay: { uygulandi: _mem.length } });  /* YETKI_FAZ5B */\n' + AP, 1)

# 3) uyelik -> log
MM = '      sendJson(response, 200, { ok: true, eklendi: add.length, cikarildi: rem.length });'
assert s.count(MM) == 1, "membership sendJson anchor=%d" % s.count(MM)
s = s.replace(MM, '      await _yetkiLog(session.tenantId, session.userId, "uyelik", { department: did, detay: { eklendi: add.length, cikarildi: rem.length } });  /* YETKI_FAZ5B */\n' + MM, 1)

# 4) Kisiler PATCH -> log (pjStore saha'da personal_* tasir; degilse Array.isArray -> 0)
KP = '    sendJson(response, 200, result.rows[0]);'
assert s.count(KP) == 1, "Kisiler PATCH sendJson anchor=%d" % s.count(KP)
KPLOG = '''    await _yetkiLog(session.tenantId, session.userId, "kisi_yetki", { target: targetUserId, detay: { module_id, role: module_role || "viewer", dep: Array.isArray(pjStore.departments) ? pjStore.departments.length : 0, grant: Array.isArray(pjStore.personal_grant) ? pjStore.personal_grant.length : 0, deny: Array.isArray(pjStore.personal_deny) ? pjStore.personal_deny.length : 0 } });  /* YETKI_FAZ5B */
'''
s = s.replace(KP, KPLOG + KP, 1)

# 5) GET /api/tenant/yetki-log — invite'tan once
INV = "// POST /api/tenant/users/invite"
assert s.count(INV) == 1, "invite anchor=%d" % s.count(INV)
EP = '''// YETKI_FAZ5B — yetki degisiklik gunlugu okuma
{ if (url.pathname === "/api/tenant/yetki-log" && request.method === "GET") {
    try {
      const session = await requireTenantAdmin(request); const tid = session.tenantId;
      if (!tid) { sendJson(response, 403, { error: "Tenant context required." }); return; }
      const uf = url.searchParams.get("user");
      const lim = Math.max(1, Math.min(200, parseInt(url.searchParams.get("limit") || "100", 10) || 100));
      const params = [tid]; let wf = "";
      if (uf) { params.push(uf); wf = ` AND (l.target_user_id::text=$${params.length} OR l.actor_id::text=$${params.length})`; }
      params.push(lim);
      const r = await query(`SELECT l.id::text id, l.eylem, l.detay, l.ts,
              l.actor_id::text actor_id, au.full_name actor_ad, au.email actor_email,
              l.target_user_id::text target_id, tu.full_name target_ad, tu.email target_email,
              l.department_id::text dept_id, d.ad dept_ad, d.ikon dept_ikon
          FROM tenant_yetki_log l
          LEFT JOIN users au ON au.id=l.actor_id
          LEFT JOIN users tu ON tu.id=l.target_user_id
          LEFT JOIN tenant_department d ON d.id=l.department_id
         WHERE l.tenant_id::text=$1::text${wf}
         ORDER BY l.ts DESC LIMIT $${params.length}`, params);
      sendJson(response, 200, { log: r.rows });
    } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
    return;
  }
}

'''
s = s.replace(INV, EP + INV, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ5B (server) — _yetkiLog + 3 yazma-yolu log + GET /api/tenant/yetki-log")
