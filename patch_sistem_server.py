# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# SISTEM_FIX — two real bugs behind the "Bilinmeyen saha endpoint'i" report:
#   1) GET /api/saha/hata-raporu never existed (only POST writers) -> Sistem tab 404s.
#   2) POST /api/saha/oneri inserts kategori='GENEL' / durum='BEKLEMEDE', both of
#      which violate the table CHECK constraints -> every feedback submit fails.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) add the missing GET /api/saha/hata-raporu (read the report the Sistem tab renders)
rep(
'    if (method === "POST" && path === "/api/saha/hata-raporu") {',
'''    if (method === "GET" && path === "/api/saha/hata-raporu") {
      const session = await requireSahaAccess(request, ["manager", "admin"]);
      let gun = parseInt(url.searchParams.get("gun") || "7", 10);
      if (!Number.isFinite(gun) || gun < 1) gun = 7;
      if (gun > 90) gun = 90;
      const a = [session.tenantId, gun];
      const ozet = await pool.query(
        "SELECT tip, count(*)::int AS sayi FROM saha_hata_log WHERE tenant_id=$1 AND ts > now() - ($2::int * INTERVAL '1 day') GROUP BY tip ORDER BY sayi DESC", a);
      const endpointOzet = await pool.query(
        "SELECT endpoint, count(*)::int AS sayi, round(avg(duration_ms))::int AS ort_ms FROM saha_hata_log WHERE tenant_id=$1 AND ts > now() - ($2::int * INTERVAL '1 day') AND endpoint IS NOT NULL GROUP BY endpoint ORDER BY sayi DESC LIMIT 20", a);
      const userOzet = await pool.query(
        "SELECT COALESCE(u.full_name, u.email, 'Bilinmiyor') AS kullanici, count(*)::int AS sayi FROM saha_hata_log h LEFT JOIN users u ON u.id = h.user_id WHERE h.tenant_id=$1 AND h.ts > now() - ($2::int * INTERVAL '1 day') GROUP BY 1 ORDER BY sayi DESC LIMIT 20", a);
      const sonHatalar = await pool.query(
        "SELECT h.ts, h.tip, h.endpoint, h.view_adi, h.hata_mesaji FROM saha_hata_log h WHERE h.tenant_id=$1 AND h.ts > now() - ($2::int * INTERVAL '1 day') ORDER BY h.ts DESC LIMIT 50", a);
      sendJson(response, 200, {
        ozet: ozet.rows,
        endpoint_ozet: endpointOzet.rows,
        user_ozet: userOzet.rows,
        son_hatalar: sonHatalar.rows
      });
      return;
    }
    if (method === "POST" && path === "/api/saha/hata-raporu") {''',
    "get-hata-raporu")

# 2) fix the CHECK-constraint violations that break feedback submission
rep(
"""      const { kategori='GENEL', baslik, mesaj } = body;""",
"""      let { kategori='DIGER', baslik, mesaj } = body;
      if (!["HATA","OZELLIK","UI","DIGER"].includes(kategori)) kategori = "DIGER";""",
    "oneri-kategori")

rep(
"""         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,'BEKLEMEDE')`,""",
"""         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,'YENI')`,""",
    "oneri-durum")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
