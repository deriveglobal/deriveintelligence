# -*- coding: utf-8 -*-
# YETKI_FAZ4 (server) — BÖLÜMLER OTORİTER + KİŞİSEL İSTİSNA (üç ekran tek zincir).
#   Bir kişinin saha yetkisi = (üye olduğu bölüm şablonlarının BİRLEŞİMİ ∪ personal_grant) − personal_deny.
#   - _recomputeSahaCaps: departments'ı bu formülle yeniden hesaplar (tek kaynak).
#   - apply (Bölümler "uygula"): ADDITIVE push YERİNE → üyelere scope yaz + recompute (şablon = yasa; kaldırılan düşer).
#   - üyelik ekle/çıkar: etkilenenleri recompute.
#   - Kişiler PATCH: gönderilen departments(=işaretli) ile bölüm-birleşimi farkından personal_grant/deny türet+sakla
#     → kişisel istisna sonraki apply'da EZİLMEZ (üç ekran konuşur).
#   Tüketiciler (_sahaCap/_enforceSahaDept/client) yine permissions_json.departments okur — DEĞİŞMEZ.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ4" in s:
    print("[skip] zaten yamalı"); sys.exit(0)
assert "YETKI_FAZ2A" in s, "önce YETKI_FAZ2A olmalı"

# 1) _recomputeSahaCaps yardımcısı — FAZ2A GET departments'ten ÖNCE (const arrow; tüm kullanımlardan önce tanımlı)
GETDEP = 'if (request.method === "GET" && url.pathname === "/api/tenant/departments") {  /* YETKI_FAZ2A */'
assert s.count(GETDEP) == 1, "GET departments anchor=%d" % s.count(GETDEP)
HELPER = '''/* YETKI_FAZ4 — kisi saha yetkisi = (bolum sablonlari birlesimi ∪ personal_grant) − personal_deny. Otoriter Bolumler + kisisel istisna. Tek kaynak. */
const _sahaDeptUnion = async (tenantId, userId) => {
  const dr = await query(`SELECT d.template_json FROM tenant_department d JOIN tenant_department_membership m ON m.department_id=d.id AND m.tenant_id=d.tenant_id WHERE d.tenant_id::text=$1::text AND m.user_id=$2`, [tenantId, userId]);
  const U = new Set();
  for (const row of dr.rows) { const caps = (row.template_json && row.template_json.capabilities) || []; if (Array.isArray(caps)) caps.forEach(c => U.add(c)); }
  return U;
};
const _recomputeSahaCaps = async (tenantId, userId) => {
  const U = await _sahaDeptUnion(tenantId, userId);
  const pr = await query(`SELECT permissions_json FROM tenant_user_modules WHERE tenant_id::text=$1::text AND user_id=$2 AND module_id='saha'`, [tenantId, userId]);
  if (!pr.rowCount) return;
  const pj = pr.rows[0].permissions_json || {};
  const grant = Array.isArray(pj.personal_grant) ? pj.personal_grant : [];
  const deny = Array.isArray(pj.personal_deny) ? pj.personal_deny : [];
  grant.forEach(c => U.add(c));
  deny.forEach(c => U.delete(c));
  const newPj = Object.assign({}, pj, { departments: Array.from(U) });
  await query(`UPDATE tenant_user_modules SET permissions_json=$3::jsonb, updated_at=now() WHERE tenant_id::text=$1::text AND user_id=$2 AND module_id='saha'`, [tenantId, userId, JSON.stringify(newPj)]);
};
'''
s = s.replace(GETDEP, HELPER + GETDEP, 1)

# 2) apply: additive push -> scope yaz + recompute
APPLY_OLD = '''      const tpl = dr.rows[0].template_json || {}; const caps = Array.isArray(tpl.capabilities) ? tpl.capabilities : [];
      const scope = tpl.scope || { level: "kendi", regions: [], segments: [] };
      const upd = await query(`UPDATE tenant_user_modules t
          SET permissions_json = jsonb_set(
                jsonb_set(COALESCE(t.permissions_json,'{}'::jsonb), '{departments}',
                  COALESCE((SELECT jsonb_agg(DISTINCT e) FROM (
                      SELECT jsonb_array_elements_text(COALESCE(t.permissions_json->'departments','[]'::jsonb)) e
                      UNION SELECT jsonb_array_elements_text($2::jsonb) e) u), '[]'::jsonb)),
                '{scope}', $3::jsonb)
          WHERE t.tenant_id::text=$1::text AND t.module_id='saha'
            AND t.user_id IN (SELECT user_id FROM tenant_department_membership WHERE department_id=$4 AND tenant_id::text=$1::text)`,
        [tid, JSON.stringify(caps), JSON.stringify(scope), did]);
      sendJson(response, 200, { ok: true, uygulandi: upd.rowCount });'''
assert s.count(APPLY_OLD) == 1, "apply body anchor=%d" % s.count(APPLY_OLD)
APPLY_NEW = '''      const tpl = dr.rows[0].template_json || {};
      const scope = tpl.scope || { level: "kendi", regions: [], segments: [] };
      /* YETKI_FAZ4 — additive push YERINE: uyelere bu bolumun scope'unu yaz + yetkiyi yeniden hesapla (sablon=yasa; kisisel istisna korunur). */
      const _mem = (await query(`SELECT user_id FROM tenant_department_membership WHERE department_id=$1 AND tenant_id::text=$2::text`, [did, tid])).rows.map(r => r.user_id);
      for (const uid of _mem) {
        await query(`UPDATE tenant_user_modules SET permissions_json=jsonb_set(COALESCE(permissions_json,'{}'::jsonb),'{scope}',$3::jsonb) WHERE tenant_id::text=$1::text AND user_id=$2 AND module_id='saha'`, [tid, uid, JSON.stringify(scope)]);
        await _recomputeSahaCaps(tid, uid);
      }
      sendJson(response, 200, { ok: true, uygulandi: _mem.length });'''
s = s.replace(APPLY_OLD, APPLY_NEW, 1)

# 3) uyelik ekle/cikar: etkilenenleri recompute
MEM_OLD = '''      if (rem.length) await query(`DELETE FROM tenant_department_membership WHERE tenant_id::text=$1::text AND department_id=$2 AND user_id = ANY($3::uuid[])`, [session.tenantId, did, rem]);
      sendJson(response, 200, { ok: true, eklendi: add.length, cikarildi: rem.length });'''
assert s.count(MEM_OLD) == 1, "membership anchor=%d" % s.count(MEM_OLD)
MEM_NEW = '''      if (rem.length) await query(`DELETE FROM tenant_department_membership WHERE tenant_id::text=$1::text AND department_id=$2 AND user_id = ANY($3::uuid[])`, [session.tenantId, did, rem]);
      for (const uid of [...add, ...rem]) { try { await _recomputeSahaCaps(session.tenantId, uid); } catch (_) {} }  /* YETKI_FAZ4 — uyelik degisince yeniden hesap */
      sendJson(response, 200, { ok: true, eklendi: add.length, cikarildi: rem.length });'''
s = s.replace(MEM_OLD, MEM_NEW, 1)

# 4) Kisiler PATCH: personal_grant/deny turet + sakla
PATCH_OLD = '''    const result = await query(`
      INSERT INTO tenant_user_modules (tenant_id, user_id, module_id, module_role, permissions_json, active, granted_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (tenant_id, user_id, module_id) DO UPDATE
        SET module_role = EXCLUDED.module_role, permissions_json = EXCLUDED.permissions_json,
            active = EXCLUDED.active, granted_by = EXCLUDED.granted_by, updated_at = now()
      RETURNING *`,
      [session.tenantId, targetUserId, module_id, module_role || "viewer",
       permissions_json || {}, active !== false, session.userId]);'''
assert s.count(PATCH_OLD) == 1, "Kisiler PATCH anchor=%d" % s.count(PATCH_OLD)
PATCH_NEW = '''    /* YETKI_FAZ4 — Kisiler = kisiye ozel istisna: gonderilen departments(=isaretli) ile bolum-birlesimi farkindan personal_grant/deny turet, sakla (sonraki apply EZMEZ). */
    let pjStore = permissions_json || {};
    if (module_id === 'saha') {
      const _U = await _sahaDeptUnion(session.tenantId, targetUserId);
      const _D = Array.isArray(pjStore.departments) ? pjStore.departments : [];
      const _grant = _D.filter(x => !_U.has(x));
      const _deny = Array.from(_U).filter(x => !_D.includes(x));
      pjStore = Object.assign({}, pjStore, { personal_grant: _grant, personal_deny: _deny });
    }
    const result = await query(`
      INSERT INTO tenant_user_modules (tenant_id, user_id, module_id, module_role, permissions_json, active, granted_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (tenant_id, user_id, module_id) DO UPDATE
        SET module_role = EXCLUDED.module_role, permissions_json = EXCLUDED.permissions_json,
            active = EXCLUDED.active, granted_by = EXCLUDED.granted_by, updated_at = now()
      RETURNING *`,
      [session.tenantId, targetUserId, module_id, module_role || "viewer",
       pjStore, active !== false, session.userId]);'''
s = s.replace(PATCH_OLD, PATCH_NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ4 (server) — recompute helper + apply/uyelik/Kisiler hook (Bolumler otoriter + kisisel istisna)")
