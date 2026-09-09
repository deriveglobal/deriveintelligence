#!/usr/bin/env python3
# YORUM_AKISI_ODAK_V1 (server) — Yorumlar akisini ODAK'a cevir: tum-yorum firehose yerine
#   kullanicinin OKUNMAMIS yorum bildirimleri (bi_bildirim: '💬 Ziyaret yorumu'/'💬 Duyuru yorumu').
#   Bunlar zaten yalniz ILGILI kisilere olusur (ziyaret sahibi + onceki yorumcular = 'bana gelen +
#   yeni'). Boylece badge (okunmamis) = liste → tutarsizlik biter, muduru yuzlerce yorum bogmaz.
#   Onkosul: YORUM_AKISI_V1 (birlesik union) CANLI. Idempotent (marker: YORUM_AKISI_ODAK_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_AKISI_ODAK_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''      const params = [tid];
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
         ORDER BY created_at DESC LIMIT 30`, params);'''
new = '''      const r = await pool.query(  /* ''' + MARK + ''' — odak: okunmamis ilgili yorum bildirimleri */
        `SELECT tip AS tur, (data->>'id') AS ref_id, baslik, govde, created_at
           FROM bi_bildirim
          WHERE tenant_id=$1 AND user_id=$2 AND okundu=false
            AND (baslik LIKE '💬 Ziyaret yorumu%' OR baslik LIKE '💬 Duyuru yorumu%')
          ORDER BY created_at DESC LIMIT 50`, [tid, uid]);'''
if old not in src:
    print("HATA: YORUM_AKISI_V1 union sorgu anchor bulunamadi (V1 canli mi?)"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] yorum-akisi → odak (bi_bildirim okunmamis)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
