#!/usr/bin/env python3
# MUSTERI_OLAYLAR_ZIYARET_FIX_V1 (server) — Hata: Musteri Karti "Hareketler"de ziyaretler
#   listelenmiyor (sayac "ziyaret 13" der ama liste bos). Kok-neden: /olaylar ziyaret alt-sorgusu
#   saha_ziyaret'ten VAR OLMAYAN iki kolonu seciyor: `lokasyon_adi` (gercekte lokasyon_id ->
#   saha_musteri_lokasyon.ad) ve `foto_sayisi` (gercekte saha_ziyaret_foto alt-sorgusu). Sorgu
#   "column does not exist" atiyor, q() yutuyor -> ziyaret olaylari bos. Sayaclar ayri COUNT'tan
#   geldigi icin 13 gorunuyor. (Bagimsiz, onceden var olan sessiz hata.)
#   Fix: LEFT JOIN saha_musteri_lokasyon (l.ad AS lokasyon_adi) + foto_sayisi alt-sorgusu + z.id
#   (ileride ziyaret satirina tiklama icin). Idempotent (marker: MUSTERI_OLAYLAR_ZIYARET_FIX_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_OLAYLAR_ZIYARET_FIX_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) ziyaret sorgusu: gecerli kolonlar + z.id
old_q = '''      const ziy = await q(`SELECT ziyaret_tarihi ts, notlar, rep_id::text rid, lokasyon_adi, foto_sayisi
          FROM saha_ziyaret WHERE tenant_id=$1 AND musteri_id=$2 AND durum='TAMAMLANDI' ORDER BY ziyaret_tarihi DESC LIMIT 25`, [tid, mid]);'''
new_q = '''      const ziy = await q(`SELECT z.id, z.ziyaret_tarihi ts, z.notlar, z.rep_id::text rid, l.ad AS lokasyon_adi,
                 (SELECT count(*) FROM saha_ziyaret_foto f WHERE f.ziyaret_id = z.id)::int AS foto_sayisi  /* ''' + MARK + ''' */
          FROM saha_ziyaret z
          LEFT JOIN saha_musteri_lokasyon l ON l.id = z.lokasyon_id
         WHERE z.tenant_id=$1 AND z.musteri_id=$2 AND z.durum='TAMAMLANDI' ORDER BY z.ziyaret_tarihi DESC LIMIT 25`, [tid, mid]);'''
if old_q not in src:
    print("HATA: /olaylar ziyaret sorgu anchor bulunamadi"); sys.exit(1)
src = src.replace(old_q, new_q, 1)
print("[+] ziyaret sorgusu duzeltildi (l.ad + foto_sayisi alt-sorgu + z.id)")

# 2) ziyaret push cagrisi: zid tasi (tiklama icin)
old_p = '''      ziy.forEach(z => { if (z.rid) idSet.add(z.rid); push(z.ts, "ziyaret", "🚗", z.notlar ? ("Ziyaret — " + String(z.notlar).slice(0, 120)) : "Ziyaret", (z.lokasyon_adi ? "📍" + z.lokasyon_adi : "") + (Number(z.foto_sayisi) ? " · 📷" + z.foto_sayisi : ""), z.rid); });'''
new_p = '''      ziy.forEach(z => { if (z.rid) idSet.add(z.rid); push(z.ts, "ziyaret", "🚗", z.notlar ? ("Ziyaret — " + String(z.notlar).slice(0, 120)) : "Ziyaret", (z.lokasyon_adi ? "📍" + z.lokasyon_adi : "") + (Number(z.foto_sayisi) ? " · 📷" + z.foto_sayisi : ""), z.rid, { zid: z.id }); });  /* ''' + MARK + ''' */'''
if old_p not in src:
    print("HATA: /olaylar ziyaret push anchor bulunamadi"); sys.exit(1)
src = src.replace(old_p, new_p, 1)
print("[+] ziyaret push'a zid eklendi (tiklama icin)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
