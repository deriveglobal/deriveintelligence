#!/usr/bin/env python3
# YORUM_AKISI_V1 (server) — Bugun "Yorumlar" karti: BIRLESIK (ziyaret + duyuru) yorum akisi ucu.
#   GET /api/saha/yorum-akisi → {yorumlar:[...], okunmamis:N}. Her satir: tur ('ziyaret'|'duyuru'),
#   ref_id (ziyaret_id / duyuru_id), user_adi, rol, icerik, created_at, baslik (firma / duyuru basligi), goruldu.
#   Kapsam: ziyaret yorumlari rol-bazli (manager/admin tum ekip, rep z.rep_id=uid OR y.user_id=uid);
#   duyuru yorumlari HERKESE ACIK (duyuru zaten yayin). okunmamis = bi_bildirim ziyaret+duyuru yorumu okunmamis.
#   Idempotent (marker: YORUM_AKISI_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_AKISI_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

anchor = '''    // SESSIZ_HATA_V1 — ziyaret yorumlari (tablo + arayuz VARDI, route YOKTU)
    if (path.startsWith("/api/saha/ziyaretler/") && path.endsWith("/yorumlar")) {'''
endpoint = '''    // ''' + MARK + ''' — Bugun "Yorumlar" karti: birlesik (ziyaret + duyuru) yorum akisi + okunmamis
    if (method === "GET" && path === "/api/saha/yorum-akisi") {
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId;
      const params = [tid];
      let ziyScope = "";
      if (session.sahaRole === "rep") { params.push(uid); ziyScope = " AND (z.rep_id = $2 OR y.user_id = $2)"; }
      const r = await pool.query(
        `(SELECT 'ziyaret' AS tur, y.ziyaret_id::text AS ref_id, y.user_adi, y.rol, LEFT(y.icerik,140) AS icerik, y.created_at, m.firma AS baslik,
                 EXISTS(SELECT 1 FROM saha_ziyaret_gorulme g WHERE g.ziyaret_id=y.ziyaret_id AND g.user_id<>y.user_id AND g.gorulme_at>=y.created_at) AS goruldu
            FROM saha_ziyaret_yorum y
            JOIN saha_ziyaret z ON z.id = y.ziyaret_id
            LEFT JOIN saha_musteri m ON m.id = z.musteri_id
           WHERE y.tenant_id = $1${ziyScope})
         UNION ALL
         (SELECT 'duyuru' AS tur, dy.duyuru_id::text AS ref_id, dy.user_adi, dy.rol, LEFT(dy.icerik,140) AS icerik, dy.created_at, d.baslik AS baslik,
                 NULL::boolean AS goruldu
            FROM saha_duyuru_yorum dy
            JOIN saha_duyuru d ON d.id = dy.duyuru_id
           WHERE dy.tenant_id = $1)
         ORDER BY created_at DESC LIMIT 30`, params);
      let okunmamis = 0;
      try {
        const u = await pool.query("SELECT COUNT(*) n FROM bi_bildirim WHERE tenant_id=$1 AND user_id=$2 AND okundu=false AND (baslik LIKE '💬 Ziyaret yorumu%' OR baslik LIKE '💬 Duyuru yorumu%')", [tid, uid]);
        okunmamis = u.rows[0] ? Number(u.rows[0].n) : 0;
      } catch (e) {}
      sendJson(response, 200, { yorumlar: r.rows, okunmamis });
      return;
    }

'''
if anchor not in src:
    print("HATA: yorumlar route anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor, endpoint + anchor, 1)
print("[+] GET /api/saha/yorum-akisi (birlesik) eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
