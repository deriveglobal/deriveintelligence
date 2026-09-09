#!/usr/bin/env python3
# YORUM_AKISI_TUMU_V1 (server) — GET /api/saha/yorum-akisi'ye ?mod=tumu: okunmus+okunmamis tum
#   yorum bildirimleri (okundu bayragiyla, LIMIT 100). Varsayilan (odak) DEGISMEZ. Onkosul: ODAK canli.
#   Idempotent (marker: YORUM_AKISI_TUMU_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_AKISI_TUMU_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''      const r = await pool.query(  /* YORUM_AKISI_ODAK_V1 — odak: okunmamis ilgili yorum bildirimleri */
        `SELECT tip AS tur, (data->>'id') AS ref_id, baslik, govde, created_at
           FROM bi_bildirim
          WHERE tenant_id=$1 AND user_id=$2 AND okundu=false
            AND (baslik LIKE '💬 Ziyaret yorumu%' OR baslik LIKE '💬 Duyuru yorumu%')
          ORDER BY created_at DESC LIMIT 50`, [tid, uid]);'''
new = '''      const _tumu = url.searchParams.get("mod") === "tumu";  /* ''' + MARK + ''' */
      const r = _tumu
        ? await pool.query(
            `SELECT tip AS tur, (data->>'id') AS ref_id, baslik, govde, created_at, okundu
               FROM bi_bildirim
              WHERE tenant_id=$1 AND user_id=$2
                AND (baslik LIKE '💬 Ziyaret yorumu%' OR baslik LIKE '💬 Duyuru yorumu%')
                AND created_at >= date_trunc('year', (now() AT TIME ZONE 'Europe/Istanbul'))
              ORDER BY created_at DESC LIMIT 200`, [tid, uid])
        : await pool.query(  /* YORUM_AKISI_ODAK_V1 — odak: okunmamis ilgili yorum bildirimleri */
            `SELECT tip AS tur, (data->>'id') AS ref_id, baslik, govde, created_at, false AS okundu
               FROM bi_bildirim
              WHERE tenant_id=$1 AND user_id=$2 AND okundu=false
                AND (baslik LIKE '💬 Ziyaret yorumu%' OR baslik LIKE '💬 Duyuru yorumu%')
              ORDER BY created_at DESC LIMIT 50`, [tid, uid]);'''
if old not in src:
    print("HATA: ODAK sorgu anchor bulunamadi (ODAK canli mi?)"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] yorum-akisi ?mod=tumu eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
