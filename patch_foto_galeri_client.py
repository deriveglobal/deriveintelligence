#!/usr/bin/env python3
# FOTO_GALERI_V1 (client) — Hata (Ali Kemal Picakci 29.07): "Aktivite girerken resim yuklemede
#   galeriden resim secmiyor, sadece kameraya izin veriyor."
#   Sebep: ziyaret foto input'larinda capture="environment" → iOS WKWebView dogrudan kameraya gidiyor,
#   "Fotograf Kitapligi" secenegini gizliyor. capture kaldirilinca native secici (Kitaplik + Cek + Gozat) acilir.
#   Kamera hala mevcut (bir dokunus uzakta). dy-file zaten capture'sizdi ve galeriden calisiyordu → kanit.
#   Etkilenen input'lar: zf-foto (ziyaret/aktivite formu — bildirilen), zd-foto (ziyaret duzenle), pt-foto (plan-tamamla).
#   Idempotent: capture kaldirildiktan sonra tekrar calisinca degisiklik yok.
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src

IDS = ["zf-foto", "zd-foto", "pt-foto"]
touched, already, missing = [], [], []
for _id in IDS:
    old = 'id="%s" accept="image/*" capture="environment" multiple hidden' % _id
    new = 'id="%s" accept="image/*" multiple hidden' % _id
    clean = 'id="%s" accept="image/*" multiple hidden' % _id
    if old in src:
        src = src.replace(old, new, 1)
        touched.append(_id)
    elif clean in src:
        already.append(_id)
    else:
        missing.append(_id)

print("[+] capture kaldirildi:", touched or "-")
if already: print("[=] zaten temiz:", already)
if missing: print("[!] BULUNAMADI (anchor kacti?):", missing)

# En az bildirilen input (zf-foto) ele alinmali; hicbiri eslesmediyse dur.
if not touched and not already:
    print("HATA: hicbir foto input anchor eslesmedi — dosya bayat olabilir"); sys.exit(1)
if "zf-foto" in missing:
    print("HATA: zf-foto (bildirilen aktivite formu) bulunamadi"); sys.exit(1)

# Kalan capture="environment" var mi? (bilgi amacli)
kalan = src.count('capture="environment"')
print("[i] kalan capture=\"environment\":", kalan)

if src == orig:
    print("[=] Degisiklik yok (idempotent)")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
