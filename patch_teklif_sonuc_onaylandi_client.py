#!/usr/bin/env python3
# TEKLIF_SONUC_ONAYLANDI_V1 (client) — Ozellik (Ali Kemal Picakci 03.08): verdigimiz teklif bizde
#   kalmadiginda teklife girip "rakipte kaldi" secip rakip fiyat/bilgi girip kayip satis olarak saklama.
#   Mevcut: teklifSonucModal(KAYBEDILDI) rakip marka/model/fiyat + kayip nedeni yakalar; KAYBEDILDI
#   teklifler saklanir + /api/saha/rapor/teklif'te analiz edilir. EKSIK: "✕ Kaybettik / ✓ Kazandik"
#   butonu yalniz durum=SUNULDU'da cikiyordu. Onaylanip verilen ama "Sun" edilmemis teklif ONAYLANDI'da
#   kaliyor → sonuc islenemiyordu.
#   Fix: Kaybettik/Kazandik butonlarini ONAYLANDI'da da goster (SUNULDU + ONAYLANDI). Handler'lar
#   (td-kaybet/td-kazan → teklifSonucModal) zaten var; sunucu action:sonuc ONAYLANDI'dan KAYBEDILDI'ya
#   izin veriyor. Idempotent (marker: TEKLIF_SONUC_ONAYLANDI_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "TEKLIF_SONUC_ONAYLANDI_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''      ${t.durum === "SUNULDU" ? `
        <button class="btn kucuk kirmizi-btn" id="td-kaybet">✕ Kaybettik</button>
        <button class="btn kucuk" id="td-kazan">✓ Kazandık</button>` : ""}'''
new = '''      ${["ONAYLANDI","SUNULDU"].includes(t.durum) ? `
        <button class="btn kucuk kirmizi-btn" id="td-kaybet">✕ Kaybettik</button>
        <button class="btn kucuk" id="td-kazan">✓ Kazandık</button>` : ""}  <!-- ''' + MARK + ''' -->'''
if old not in src:
    print("HATA: SUNULDU kaybet/kazan anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] Kaybettik/Kazandik ONAYLANDI'da da gosteriliyor")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
