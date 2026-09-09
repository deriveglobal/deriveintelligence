# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "HARITA_ILSAHA_V1"

def patch(rel, edits):
    path = os.path.join(BASE, rel)
    with io.open(path, encoding="utf-8") as f: orig = f.read()
    if MARK in orig:
        print("SKIP (zaten var):", rel); return
    s = orig
    for name, old, new in edits:
        c = s.count(old)
        assert c == 1, "ANCHOR %s bulundu=%d (beklenen 1) -> %s" % (name, c, rel)
        s = s.replace(old, new)
    if not os.path.exists(path + ".ilsahabak"):
        with io.open(path + ".ilsahabak", "w", encoding="utf-8") as f: f.write(orig)
    with io.open(path, "w", encoding="utf-8") as f: f.write(s)
    print("OK", rel, "| ILSAHA:", s.count(MARK))

# 1) cap map
C1o = '''    "/api/saha/harita-il-metrikler": ["harita"],'''
C1n = '''    "/api/saha/harita-il-metrikler": ["harita"],
    "/api/saha/harita-il-saha": ["harita"],  /* HARITA_ILSAHA_V1 */'''

# 2) yeni uc — il basina musteri + ziyaret + kapsam (Firsat/Kapsam mercekleri icin)
E1o = '''    if (method === "GET" && path === "/api/saha/harita-il-cariler") { /* HARITA_IL_CARILER_V1 — il tile drill-down: cari kırılımı */'''
E1n = '''    if (method === "GET" && path === "/api/saha/harita-il-saha") { /* HARITA_ILSAHA_V1 — il basina musteri + ziyaret + kapsam (Firsat/Kapsam mercekleri) */
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const sp = new URL(request.url, "http://x").searchParams;
      const f = sp.get("from") || null, t = sp.get("to") || null;
      const tip = ["TUKETICI","TICARI"].includes(sp.get("tip")) ? sp.get("tip") : null;
      const T = session.tenantId;
      try {
        const r = await query(
          "SELECT sm.il il,"
          + " COUNT(DISTINCT sm.id)::int musteri,"
          + " COUNT(DISTINCT sm.id) FILTER (WHERE sm.tip='TUKETICI')::int musteri_tuk,"
          + " COUNT(DISTINCT sm.id) FILTER (WHERE sm.tip='TICARI')::int musteri_tic,"
          + " COUNT(z.id) FILTER (WHERE z.durum='TAMAMLANDI' AND ($2::date IS NULL OR z.ziyaret_tarihi BETWEEN $2 AND $3))::int ziyaret,"
          + " COUNT(DISTINCT sm.id) FILTER (WHERE EXISTS (SELECT 1 FROM saha_ziyaret zz WHERE zz.musteri_id=sm.id AND zz.tenant_id=sm.tenant_id AND zz.durum='TAMAMLANDI' AND ($2::date IS NULL OR zz.ziyaret_tarihi BETWEEN $2 AND $3)))::int ziyaret_edilen"
          + " FROM saha_musteri sm LEFT JOIN saha_ziyaret z ON z.musteri_id=sm.id AND z.tenant_id=sm.tenant_id"
          + " WHERE sm.tenant_id=$1 AND sm.aktif=true AND sm.il IS NOT NULL AND sm.il<>'' AND ($4::text IS NULL OR sm.tip=$4)"
          + " GROUP BY sm.il", [T, f, t, tip]);
        const iller = r.rows.map(x => {
          const m = Number(x.musteri||0), ze = Number(x.ziyaret_edilen||0);
          return { il: x.il, musteri: m, musteri_tuk: Number(x.musteri_tuk||0), musteri_tic: Number(x.musteri_tic||0), ziyaret: Number(x.ziyaret||0), ziyaret_edilen: ze, kapsam_pct: m > 0 ? Math.round(ze / m * 100) : 0 };
        });
        sendJson(response, 200, { iller });
      } catch (e) { console.error("[il-saha]", e && e.message); sendJson(response, 500, { error: "il-saha alinamadi" }); }
      return;
    }
    if (method === "GET" && path === "/api/saha/harita-il-cariler") { /* HARITA_IL_CARILER_V1 — il tile drill-down: cari kırılımı */'''

patch("server_container.mjs", [("C1", C1o, C1n), ("E1", E1o, E1n)])
print("BITTI.")
