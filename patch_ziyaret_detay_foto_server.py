#!/usr/bin/env python3
# ZIYARET_DETAY_FOTO_V1 (server) — Hata: ziyarete yuklenen fotolar mobil uygulamada gorunmuyor.
#   Kok-neden: ziyaretDetayModal fotolari yalniz `Number(z.foto_sayisi)` dogruysa cekiyor.
#   Ama TEKIL ziyaret ucu GET /api/saha/ziyaretler/:id `SELECT z.*` donuyor; foto_sayisi YOK
#   (o sayac yalniz LISTE sorgusunda var). Detay modal once tam kaydi cektigi icin z.foto_sayisi
#   undefined → Number(undefined)=NaN → foto blogu HIC calismiyor. Yukleme/CSP sorunu degil.
#   Fix: tekil ziyaret sorgusuna foto_sayisi alt-sorgusu ekle. Idempotent (marker: ZIYARET_DETAY_FOTO_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "ZIYARET_DETAY_FOTO_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''               mu.sektorler, mu.tedarikci_markalar, mu.durum AS musteri_durum,
               u.full_name AS rep_adi
          FROM saha_ziyaret z'''
new = '''               mu.sektorler, mu.tedarikci_markalar, mu.durum AS musteri_durum,
               u.full_name AS rep_adi,
               (SELECT count(*) FROM saha_ziyaret_foto f WHERE f.ziyaret_id = z.id)::int AS foto_sayisi  /* ''' + MARK + ''' */
          FROM saha_ziyaret z'''
if old not in src:
    print("HATA: tekil ziyaret GET anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] Tekil ziyaret sorgusuna foto_sayisi eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
