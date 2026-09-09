# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "IK_BOLUM_V1"
SRV = os.path.join(BASE, "server_container.mjs")
CLI = os.path.join(BASE, "shells", "tenant-admin.js")
with io.open(SRV, encoding="utf-8") as f: srv = f.read()
with io.open(CLI, encoding="utf-8") as f: cli = f.read()
if MARK in srv and MARK in cli:
    print("SKIP (zaten var)"); raise SystemExit
S1o = '  deny.forEach(c => U.delete(c));\n  const newPj = Object.assign({}, pj, { departments: Array.from(U) });'
S1n = '  deny.forEach(c => U.delete(c));\n  ["ikodasi","finansodasi"].forEach(c => U.delete(c));  /* IK_BOLUM_V1 */\n  const newPj = Object.assign({}, pj, { departments: Array.from(U) });'
FUNC = r'''/* IK_BOLUM_V1 — oda capleri (ikodasi/finansodasi) bolum sablonundan intelligence moduluine senkron */
const _recomputeMgmtRooms = async (tenantId, userId) => {
  const ROOMS = ["ikodasi","finansodasi"];
  const dr = await query(`SELECT d.template_json FROM tenant_department d JOIN tenant_department_membership m ON m.department_id=d.id AND m.tenant_id::text=d.tenant_id::text WHERE m.user_id=$2 AND d.tenant_id::text=$1::text`, [tenantId, userId]);
  const wanted = new Set();
  for (const row of dr.rows) { const caps = (row.template_json && Array.isArray(row.template_json.capabilities)) ? row.template_json.capabilities : []; ROOMS.forEach(c => { if (caps.includes(c)) wanted.add(c); }); }
  const ir = await query(`SELECT permissions_json FROM tenant_user_modules WHERE tenant_id::text=$1::text AND user_id=$2 AND module_id='intelligence'`, [tenantId, userId]);
  if (!ir.rowCount) {
    if (!wanted.size) return;
    const pj0 = { departments: Array.from(wanted) };
    await query(`INSERT INTO tenant_user_modules (tenant_id, user_id, module_id, module_role, permissions_json, active) VALUES ($1,$2,'intelligence','viewer',$3::jsonb,true) ON CONFLICT (tenant_id,user_id,module_id) DO UPDATE SET permissions_json=EXCLUDED.permissions_json, active=true, updated_at=now()`, [tenantId, userId, JSON.stringify(pj0)]);
    return;
  }
  const pj = ir.rows[0].permissions_json || {};
  const depts = new Set(Array.isArray(pj.departments) ? pj.departments : []);
  const grant = Array.isArray(pj.personal_grant) ? pj.personal_grant : [];
  const deny = Array.isArray(pj.personal_deny) ? pj.personal_deny : [];
  ROOMS.forEach(c => { if (wanted.has(c) || grant.includes(c)) depts.add(c); else depts.delete(c); });
  deny.forEach(c => { if (ROOMS.includes(c)) depts.delete(c); });
  const newPj = Object.assign({}, pj, { departments: Array.from(depts) });
  await query(`UPDATE tenant_user_modules SET permissions_json=$3::jsonb, updated_at=now() WHERE tenant_id::text=$1::text AND user_id=$2 AND module_id='intelligence'`, [tenantId, userId, JSON.stringify(newPj)]);
};
'''
S2o = 'if (request.method === "GET" && url.pathname === "/api/tenant/departments") {  /* YETKI_FAZ2A */'
S2n = FUNC + '\n' + S2o
S3o = 'for (const uid of [...add, ...rem]) { try { await _recomputeSahaCaps(session.tenantId, uid); } catch (_) {} }'
S3n = 'for (const uid of [...add, ...rem]) { try { await _recomputeSahaCaps(session.tenantId, uid); await _recomputeMgmtRooms(session.tenantId, uid); } catch (_) {} }'
S4o = 'await _recomputeSahaCaps(tid, uid);'
S4n = 'await _recomputeSahaCaps(tid, uid);\n        await _recomputeMgmtRooms(tid, uid);'
for a, o in [("S1",S1o),("S2",S2o),("S3",S3o),("S4",S4o)]:
    assert srv.count(o) == 1, a + "=%d" % srv.count(o)
srv2 = srv.replace(S1o,S1n,1).replace(S2o,S2n,1).replace(S3o,S3n,1).replace(S4o,S4n,1)
C1o = 'const groups = (MODULES.saha && MODULES.saha.groups) || [];'
C1n = 'const groups = [...((MODULES.saha && MODULES.saha.groups) || []), ["Odalar", [["ikodasi","\u0130K Odas\u0131"],["finansodasi","Finans Odas\u0131"]]]];  /* IK_BOLUM_V1 */'
assert cli.count(C1o) == 1, "C1=%d" % cli.count(C1o)
cli2 = cli.replace(C1o, C1n, 1)
if not os.path.exists(SRV+".ikbolumbak"):
    with io.open(SRV+".ikbolumbak","w",encoding="utf-8") as f: f.write(srv)
if not os.path.exists(CLI+".ikbolumbak"):
    with io.open(CLI+".ikbolumbak","w",encoding="utf-8") as f: f.write(cli)
with io.open(SRV,"w",encoding="utf-8") as f: f.write(srv2)
with io.open(CLI,"w",encoding="utf-8") as f: f.write(cli2)
print("OK server:", srv2.count(MARK), "| client:", cli2.count(MARK))
