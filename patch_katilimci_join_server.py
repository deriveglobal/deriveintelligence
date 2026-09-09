import sys, io
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
if "KATILIMCI_JOIN_V1" in s:
    print("[katilimci_join] zaten uygulanmis, atlaniyor."); sys.exit(0)
E=[
# 1) tablo
("""      CREATE INDEX IF NOT EXISTS idx_saha_foto_ziyaret   ON saha_ziyaret_foto (ziyaret_id);""",
"""      CREATE INDEX IF NOT EXISTS idx_saha_foto_ziyaret   ON saha_ziyaret_foto (ziyaret_id);
      CREATE TABLE IF NOT EXISTS saha_ziyaret_katilimci (tenant_id uuid NOT NULL, ziyaret_id uuid NOT NULL REFERENCES saha_ziyaret(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY (ziyaret_id, user_id)); -- KATILIMCI_JOIN_V1
      CREATE INDEX IF NOT EXISTS idx_saha_katilimci_user ON saha_ziyaret_katilimci (tenant_id, user_id);"""),
# 2) sync helper (POST handler'dan once; fonksiyon bildirimi hoist edilir -> PUT'ta da gorunur)
("""    if (method === "POST" && path === "/api/saha/ziyaretler") {""",
"""    async function _syncZiyaretKatilimci(tenantId, ziyaretId, repId, katilimcilar) { // KATILIMCI_JOIN_V1
      try {
        const adlar = (Array.isArray(katilimcilar) ? katilimcilar : []).filter(function (x) { return typeof x === "string" && x.trim(); });
        let uids = [];
        if (adlar.length) {
          const r = await pool.query("SELECT DISTINCT u.id FROM users u JOIN tenant_user_modules tum ON tum.user_id=u.id AND tum.module_id='saha' AND tum.tenant_id=$1 AND tum.active=true WHERE u.status<>'disabled' AND COALESCE(u.full_name,u.email)=ANY($2::text[]) AND u.id<>$3", [tenantId, adlar, repId]);
          uids = r.rows.map(function (x) { return x.id; });
        }
        await pool.query("DELETE FROM saha_ziyaret_katilimci WHERE ziyaret_id=$1", [ziyaretId]);
        if (uids.length) await pool.query("INSERT INTO saha_ziyaret_katilimci (tenant_id, ziyaret_id, user_id) SELECT $1,$2,x FROM unnest($3::uuid[]) x ON CONFLICT DO NOTHING", [tenantId, ziyaretId, uids]);
      } catch (e) { console.error("[katilimci-join]", e && e.message); }
    }
    if (method === "POST" && path === "/api/saha/ziyaretler") {"""),
# 3) POST sync cagrisi
("""          p.detay ? JSON.stringify(p.detay) : null, p.lokasyon_id || null]);
      let _asistan = null;""",
"""          p.detay ? JSON.stringify(p.detay) : null, p.lokasyon_id || null]);
      if (p.detay && Array.isArray(p.detay.katilimcilar)) _syncZiyaretKatilimci(session.tenantId, result.rows[0].id, session.userId, p.detay.katilimcilar); // KATILIMCI_JOIN_V1
      let _asistan = null;"""),
# 4) PUT sync cagrisi (tamamla/guncelle)
("""      sendJson(response, 200, { ziyaret: result.rows[0], asistan: _asistan, duzenlendi: action === "guncelle" && !_ilkKezNot });""",
"""      if (p.detay && Array.isArray(p.detay.katilimcilar)) _syncZiyaretKatilimci(session.tenantId, result.rows[0].id, own.rows[0].rep_id, p.detay.katilimcilar); // KATILIMCI_JOIN_V1
      sendJson(response, 200, { ziyaret: result.rows[0], asistan: _asistan, duzenlendi: action === "guncelle" && !_ilkKezNot });"""),
# 5) liste gorunurluk (co-rep de gorsun)
("""      if (session.sahaRole === "rep" && !_mid) {
        params.push(session.userId);
        sql += ` AND z.rep_id = $${params.length}`;
      }""",
"""      if (session.sahaRole === "rep" && !_mid) {
        params.push(session.userId);
        sql += ` AND (z.rep_id = $${params.length} OR EXISTS(SELECT 1 FROM saha_ziyaret_katilimci k WHERE k.ziyaret_id=z.id AND k.user_id=$${params.length}))`; // KATILIMCI_JOIN_V1
      }"""),
]
for i,(o,n) in enumerate(E):
    if s.count(o)!=1:
        sys.stderr.write("[join] HATA edit %d anchor=%d\n"%(i,s.count(o))); sys.exit(2)
    s=s.replace(o,n,1)
io.open(p,"w",encoding="utf-8").write(s)
print("[katilimci_join] uygulandi (5 edit).")
