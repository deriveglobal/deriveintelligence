#!/usr/bin/env python3
# ZIYARET_PIN_MUSTERI_V1 (server) — "Bu konumu musteri adresine kaydet" ARTIK ISLENIYOR.
#   KOK (veriyle kanitli: 305 check-in'li ziyaret ama yalniz 2 musteri pinli): action:checkin handler'i
#   checkin_lat/lng'i ziyarete yaziyor ama client'in gonderdigi pin_musteri'yi YOK SAYIYORDU →
#   saha_musteri.lat/lng guncellenmiyordu. FIX: pin_musteri true ise musteri pinini de yaz.
#   Idempotent (marker: ZIYARET_PIN_MUSTERI_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "ZIYARET_PIN_MUSTERI_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''        `, [session.tenantId, m[1], p.lat ?? null, p.lng ?? null]);
        // İLK check-in bugünkü başlangıç noktasını belirler (Asistan rota önerisi için).'''
new = '''        `, [session.tenantId, m[1], p.lat ?? null, p.lng ?? null]);
        try { /* ''' + MARK + ''' — "bu konumu musteri adresine kaydet" isaretliyse musteri pinini yaz */
          if (p.pin_musteri && p.lat != null && p.lng != null && result.rows[0]) {
            await pool.query("UPDATE saha_musteri SET lat=$3, lng=$4, updated_at=now() WHERE tenant_id=$1 AND id=$2", [session.tenantId, result.rows[0].musteri_id, p.lat, p.lng]);
          }
        } catch (e) { try { console.warn("checkin pin_musteri:", e.message); } catch (er) {} }
        // İLK check-in bugünkü başlangıç noktasını belirler (Asistan rota önerisi için).'''
if old not in src:
    print("HATA: checkin action anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] checkin action pin_musteri -> saha_musteri UPDATE")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
