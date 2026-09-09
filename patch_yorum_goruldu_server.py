#!/usr/bin/env python3
# YORUM_GORULDU_V1 (server) — ziyaret yorumuna "✓ görüldü" icin: (1) saha_ziyaret_gorulme'yi
#   SON görme olacak sekilde guncelle (ON CONFLICT DO NOTHING → DO UPDATE gorulme_at=now()),
#   (2) GET /yorumlar her yoruma `goruldu` bayragi ekle = yorumdan SONRA yazan-disi biri ziyareti
#   gordu mu. Idempotent (marker: YORUM_GORULDU_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "YORUM_GORULDU_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) /gordum: son gorme (goruldu isareti dogru olsun diye)
old1 = '''        await query(`INSERT INTO saha_ziyaret_gorulme (tenant_id, ziyaret_id, user_id)
                     VALUES ($1,$2,$3) ON CONFLICT (ziyaret_id, user_id) DO NOTHING`,
          [session.tenantId, m[1], session.userId]);'''
new1 = '''        await query(`INSERT INTO saha_ziyaret_gorulme (tenant_id, ziyaret_id, user_id)
                     VALUES ($1,$2,$3) ON CONFLICT (ziyaret_id, user_id) DO UPDATE SET gorulme_at = now()`,  /* ''' + MARK + ''' — son gorme */
          [session.tenantId, m[1], session.userId]);'''
if old1 not in src:
    print("HATA: /gordum insert anchor bulunamadi"); sys.exit(1)
src = src.replace(old1, new1, 1)
print("[+] /gordum son-gorme (DO UPDATE gorulme_at)")

# 2) GET /yorumlar: goruldu bayragi
old2 = '''        const r = await pool.query(
          `SELECT id, user_adi, rol, icerik, created_at
             FROM saha_ziyaret_yorum
            WHERE tenant_id=$1 AND ziyaret_id=$2
            ORDER BY created_at ASC`,
          [session.tenantId, zid]
        );'''
new2 = '''        const r = await pool.query(
          `SELECT y.id, y.user_adi, y.rol, y.icerik, y.created_at,
                  EXISTS(SELECT 1 FROM saha_ziyaret_gorulme g
                          WHERE g.ziyaret_id=y.ziyaret_id AND g.user_id <> y.user_id
                            AND g.gorulme_at >= y.created_at) AS goruldu  /* ''' + MARK + ''' */
             FROM saha_ziyaret_yorum y
            WHERE y.tenant_id=$1 AND y.ziyaret_id=$2
            ORDER BY y.created_at ASC`,
          [session.tenantId, zid]
        );'''
if old2 not in src:
    print("HATA: GET /yorumlar select anchor bulunamadi"); sys.exit(1)
src = src.replace(old2, new2, 1)
print("[+] GET /yorumlar goruldu bayragi eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
