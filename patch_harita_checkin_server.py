#!/usr/bin/env python3
# HARITA_CHECKIN_V1 (server) — yeni uc GET /api/saha/harita-checkinler: her ziyaret check-in noktasi
#   (~100m dedup: round(lat/lng,3)) -> cok-lokasyonlu firmalar (or NUH BETON) haritada AYRI pinler.
#   Rep kendi ziyaretlerini gorur; manager/admin hepsini. Idempotent (marker: HARITA_CHECKIN_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "HARITA_CHECKIN_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

anchor = '''    if (method === "GET" && path === "/api/saha/harita-musteriler") { /* HARITA_MUSTERI_V1 */'''
endpoint = '''    if (method === "GET" && path === "/api/saha/harita-checkinler") { /* ''' + MARK + ''' — her ziyaret check-in noktasi (~100m dedup); cok-lokasyon firmalar haritada ayri pinler */
      const session = await requireSahaAccess(request, ["rep","manager","admin"]);
      const sp = new URL(request.url, "http://x").searchParams;
      const tip = ["TUKETICI","TICARI"].includes(sp.get("tip")) ? sp.get("tip") : null;
      const binds = [session.tenantId];
      let repW = "";
      if (session.sahaRole === "rep") { binds.push(session.userId); repW = " AND z.rep_id = $" + binds.length; }
      let tipW = "";
      if (tip) { binds.push(tip); tipW = " AND m.tip = $" + binds.length; }
      try {
        const r = await query(
          "SELECT m.id musteri_id, m.firma, m.tip, m.il, m.ilce,"
          + " round(z.checkin_lat::numeric,3)::float8 lat, round(z.checkin_lng::numeric,3)::float8 lng,"
          + " MAX(z.ziyaret_tarihi) son, COUNT(*)::int adet"
          + " FROM saha_ziyaret z JOIN saha_musteri m ON m.id = z.musteri_id"
          + " WHERE z.tenant_id = $1 AND z.checkin_lat IS NOT NULL" + repW + tipW
          + " GROUP BY m.id, m.firma, m.tip, m.il, m.ilce, round(z.checkin_lat::numeric,3), round(z.checkin_lng::numeric,3)",
          binds);
        sendJson(response, 200, { noktalar: r.rows });
      } catch (e) { console.error("[harita-checkin]", e && e.message); sendJson(response, 500, { error: "checkin noktalari alinamadi" }); }
      return;
    }

'''
if anchor not in src:
    print("HATA: harita-musteriler anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor, endpoint + anchor, 1)
print("[+] GET /api/saha/harita-checkinler eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
