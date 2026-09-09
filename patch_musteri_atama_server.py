# -*- coding: utf-8 -*-
# MUSTERI_ATAMA_V1 (server) — Yonetim konsolu Musteri Atama:
#   GET  /api/tenant/musteri-atama          — tum aktif musteri + temsilci listesi (tenant admin)
#   POST /api/tenant/musteri-atama          — {musteri_ids[], hedef_rep} toplu/tekil ata (eski->yeni log)
#   GET  /api/tenant/musteri-atama/gecmis   — bir musterinin atama gecmisi
#   Log: saha_musteri_aksiyon (rapor='atama', tur='ATA', eski_rep+hedef_rep). requireTenantAdmin.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MUSTERI_ATAMA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

anchor = "// PATCH /api/tenant/users/:id/modules"
assert s.count(anchor) == 1, "anchor=%d" % s.count(anchor)

BLOCK = r'''if (request.method === "GET" && url.pathname === "/api/tenant/musteri-atama") {  /* MUSTERI_ATAMA_V1 */
  try {
    const session = await requireTenantAdmin(request);
    if (!session.tenantId) { sendJson(response, 403, { error: "Tenant context required." }); return; }
    const tid = session.tenantId;
    const rp = await query(`
      SELECT u.id::text id, COALESCE(u.full_name, u.email, '—') ad
        FROM users u
       WHERE u.id IN (
         SELECT user_id FROM tenant_user_modules WHERE tenant_id::text=$1::text AND module_id='saha' AND active=true
         UNION SELECT DISTINCT sorumlu_rep FROM saha_musteri WHERE tenant_id::text=$1::text AND sorumlu_rep IS NOT NULL
       ) ORDER BY ad`, [tid]);
    const r = await query(`
      WITH ciro AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari
                     WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu),
           son AS (SELECT musteri_id, MAX(ziyaret_tarihi) mx FROM saha_ziyaret
                     WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' GROUP BY musteri_id)
      SELECT m.id::text id, m.firma, m.il, m.ilce, m.tip, to_jsonb(m)->>'segment' segment,
             m.musteri_kodu, m.sorumlu_rep::text rid, COALESCE(c.yil,0)::numeric ciro, s.mx son
        FROM saha_musteri m
        LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
        LEFT JOIN son s ON s.musteri_id=m.id
       WHERE m.tenant_id::text=$1::text AND m.aktif=true
       ORDER BY m.firma`, [tid]);
    const now = Date.now();
    const gunOf = (mx) => { if (!mx) return null; const d = new Date(mx); return isNaN(d) ? null : Math.max(0, Math.floor((now - d.getTime()) / 86400000)); };
    const nameMap = {}; for (const x of rp.rows) nameMap[x.id] = x.ad;
    const musteriler = r.rows.map((x) => ({
      id: x.id, firma: x.firma, il: x.il, ilce: x.ilce, tip: x.tip, segment: x.segment || null,
      kod: x.musteri_kodu || null, rep_id: x.rid || null, rep: x.rid ? (nameMap[x.rid] || null) : null,
      ciro: Number(x.ciro) || 0, gun: gunOf(x.son)
    }));
    sendJson(response, 200, { temsilciler: rp.rows, musteriler });
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}

if (request.method === "POST" && url.pathname === "/api/tenant/musteri-atama") {  /* MUSTERI_ATAMA_V1 */
  try {
    const session = await requireTenantAdmin(request);
    if (!session.tenantId) { sendJson(response, 403, { error: "Tenant context required." }); return; }
    const tid = session.tenantId, uid = session.userId;
    const b = await readJson(request);
    const ids = Array.isArray(b.musteri_ids) ? b.musteri_ids.filter(Boolean) : (b.musteri_id ? [b.musteri_id] : []);
    const hedef = b.hedef_rep || null;
    if (!ids.length || !hedef) { sendJson(response, 400, { error: "musteri_ids ve hedef_rep gerekli" }); return; }
    const hv = await query(`SELECT 1 FROM tenant_users WHERE tenant_id::text=$1::text AND user_id::text=$2::text AND active=true`, [tid, hedef]);
    if (!hv.rowCount) { sendJson(response, 400, { error: "geçersiz temsilci" }); return; }
    let n = 0;
    for (const mid of ids) {
      const cur = await query(`SELECT sorumlu_rep::text rid FROM saha_musteri WHERE tenant_id::text=$1::text AND id=$2`, [tid, mid]);
      if (!cur.rowCount) continue;
      const eski = cur.rows[0].rid;
      if (eski === hedef) continue;
      await query(`UPDATE saha_musteri SET sorumlu_rep=$3, updated_at=now() WHERE tenant_id::text=$1::text AND id=$2`, [tid, mid, hedef]);
      await query(`INSERT INTO saha_musteri_aksiyon (tenant_id,musteri_id,rapor,tur,aktor_id,aktor_rol,hedef_rep,eski_rep)
                   VALUES ($1,$2,'atama','ATA',$3,'admin',$4,$5)`, [tid, mid, uid, hedef, eski]);
      n++;
    }
    sendJson(response, 200, { ok: true, degisen: n });
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}

if (request.method === "GET" && url.pathname === "/api/tenant/musteri-atama/gecmis") {  /* MUSTERI_ATAMA_V1 */
  try {
    const session = await requireTenantAdmin(request);
    if (!session.tenantId) { sendJson(response, 403, { error: "Tenant context required." }); return; }
    const tid = session.tenantId;
    const mid = url.searchParams.get("musteri_id");
    if (!mid) { sendJson(response, 400, { error: "musteri_id gerekli" }); return; }
    const r = await query(`SELECT olusturma_ts ts, eski_rep::text eski, hedef_rep::text yeni, aktor_id::text aktor
        FROM saha_musteri_aksiyon
       WHERE tenant_id::text=$1::text AND musteri_id=$2 AND tur='ATA'
       ORDER BY olusturma_ts DESC LIMIT 30`, [tid, mid]);
    const ids = [...new Set(r.rows.flatMap((x) => [x.eski, x.yeni, x.aktor]).filter(Boolean))];
    const nm = {};
    if (ids.length) { const u = await query(`SELECT id::text id, COALESCE(full_name,email,'—') ad FROM users WHERE id::text = ANY($1)`, [ids]); for (const x of u.rows) nm[x.id] = x.ad; }
    sendJson(response, 200, { gecmis: r.rows.map((x) => ({ ts: x.ts, eski: x.eski ? (nm[x.eski] || '—') : null, yeni: x.yeni ? (nm[x.yeni] || '—') : null, aktor: x.aktor ? (nm[x.aktor] || '—') : null })) });
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}

'''

s = s.replace(anchor, BLOCK + anchor, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_ATAMA_V1 (server) — 3 endpoint")
