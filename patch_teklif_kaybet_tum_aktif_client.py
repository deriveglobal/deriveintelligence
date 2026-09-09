#!/usr/bin/env python3
# TEKLIF_KAYBET_TUM_AKTIF_V1 (client) — Ali Kemal 04.08: "en son guncelleme bende gozukmuyor, halen
#   rakipte kaldi secemiyorum". Kok-neden: TEKLIF_SONUC_ONAYLANDI_V1 detay butonu yalniz ONAYLANDI/
#   SUNULDU'da cikiyor. Ama sunucu (PUT /api/saha/teklifler/:id action:sonuc) kaynak durumu KISITLAMIYOR
#   (yalniz zaten KAZANILDI/KAYBEDILDI olani reddediyor). Yani TASLAK ve ONAY_BEKLIYOR tekliflerde de
#   Kaybettik/Kazandik ISLENEBILIR ama buton gorunmuyordu → Ali Kemal'in teklifi muhtemelen TASLAK/
#   ONAY_BEKLIYOR oldugu icin butonu goremiyor.
#   Fix: detay modalinda Kaybettik/Kazandik butonlarini sunucunun izin verdigi tum aktif durumlara ac:
#   ["TASLAK","ONAY_BEKLIYOR","ONAYLANDI","SUNULDU"]. Idempotent (marker: TEKLIF_KAYBET_TUM_AKTIF_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "TEKLIF_KAYBET_TUM_AKTIF_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = '''      ${["ONAYLANDI","SUNULDU"].includes(t.durum) ? `
        <button class="btn kucuk kirmizi-btn" id="td-kaybet">✕ Kaybettik</button>
        <button class="btn kucuk" id="td-kazan">✓ Kazandık</button>` : ""}  <!-- TEKLIF_SONUC_ONAYLANDI_V1 -->'''
new = '''      ${["TASLAK","ONAY_BEKLIYOR","ONAYLANDI","SUNULDU"].includes(t.durum) ? `
        <button class="btn kucuk kirmizi-btn" id="td-kaybet">✕ Kaybettik</button>
        <button class="btn kucuk" id="td-kazan">✓ Kazandık</button>` : ""}  <!-- ''' + MARK + ''' (was TEKLIF_SONUC_ONAYLANDI_V1) -->'''
if old not in src:
    print("HATA: TEKLIF_SONUC_ONAYLANDI_V1 buton blogu bulunamadi (deploy edilmis mi?)"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] Kaybettik/Kazandik tum aktif durumlarda (TASLAK/ONAY_BEKLIYOR/ONAYLANDI/SUNULDU)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
