#!/usr/bin/env python3
# MUSTERI_ARA_PROFIL_V1 (server) — "Musteri ziyaretinde girilen rakip/raf profili her seferinde bos
#   geliyor". Kok-neden: profil saha_musteri kolonlarina KAYDEDILIYOR (write-back calisiyor; DB dolu)
#   ve ziyaret detay'i da saklaniyor. AMA ziyaret formu "Musteri Sec"ten gelen `mus` ile prefill
#   ediyor (mus.raf_markalar / mus.sektorler ...), ve GET /api/saha/musteri-ara bu profil kolonlarini
#   SELECT etmiyordu → mus'ta alanlar undefined → form bos aciliyordu.
#   Fix: musteri-ara SAHA sorgusuna 10 profil kolonu ekle. Idempotent (marker: MUSTERI_ARA_PROFIL_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_ARA_PROFIL_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''        SELECT id, tip, firma, musteri_kodu, il, ilce, segment, durum, yetkili, telefon, vergi_no, tc_no
        FROM saha_musteri'''
new = '''        SELECT id, tip, firma, musteri_kodu, il, ilce, segment, durum, yetkili, telefon, vergi_no, tc_no,
               raf_markalar, bayilikler, rakip_toptancilar, kis_stok, yaz_stok,
               sektorler, tedarikci_markalar, kullanilan_markalar, arac_parki, yillik_potansiyel  /* ''' + MARK + ''' — ziyaret formu prefill icin profil */
        FROM saha_musteri'''
if old not in src:
    print("HATA: musteri-ara SAHA SELECT anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] musteri-ara SAHA sorgusuna profil kolonlari eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
