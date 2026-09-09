# -*- coding: utf-8 -*-
# RAPOR_R1B (client) — GUVEN duzeltmeleri (iki kabuk; her dosyaya kendi anchor'i):
#  5) OZET "Yeniden Kazanim" kutu=liste: modal filtresine ESKI_NOKTA eklendi (server 3 durum sayiyor: PASIF/ESKI/RISKLI).
#  1) CIRO hero "Toplam etki ciro": rep satirlarini toplamak yerine server distinct gercek toplami (d.toplam_etki_ciro) kullanir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_R1B" in s:
    print("[skip] zaten yamali"); sys.exit(0)
n = 0

def rep(old, new, label):
    global s, n
    if old in s:
        assert s.count(old) == 1, "%s anchor=%d" % (label, s.count(old))
        s = s.replace(old, new, 1); n += 1
        print("  [+] %s" % label)

# 5a) OZET ESKI_NOKTA — masaustu
rep('bindZ("rp-oz-pasif", "Yeniden Kazanım", zs => zs.filter(z => ["PASIF_NOKTA", "RISKLI_NOKTA"].includes(z.musteri_durum)));',
    'bindZ("rp-oz-pasif", "Yeniden Kazanım", zs => zs.filter(z => ["PASIF_NOKTA", "ESKI_NOKTA", "RISKLI_NOKTA"].includes(z.musteri_durum)));  /* RAPOR_R1B — kutu=liste (ESKI_NOKTA) */',
    "ozet-eski-desktop")
# 5b) OZET ESKI_NOKTA — mobil
rep('rpZiyaretListesiModal("Yeniden Kazanım", ziyaretler.filter(z => ["PASIF_NOKTA","RISKLI_NOKTA"].includes(z.musteri_durum)));',
    'rpZiyaretListesiModal("Yeniden Kazanım", ziyaretler.filter(z => ["PASIF_NOKTA","ESKI_NOKTA","RISKLI_NOKTA"].includes(z.musteri_durum)));  /* RAPOR_R1B — kutu=liste (ESKI_NOKTA) */',
    "ozet-eski-mobil")
# 1a) CIRO hero — masaustu
rep('<div class="zc-hero" style="grid-column:span 1"><div class="l">Toplam etki ciro · dönem</div><div class="n">${kisa(toplamCiro)}</div></div>',
    '<div class="zc-hero" style="grid-column:span 1"><div class="l">Toplam etki ciro · dönem</div><div class="n">${kisa((d && d.toplam_etki_ciro != null) ? d.toplam_etki_ciro : toplamCiro)}</div></div>',
    "ciro-hero-desktop")
# 1b) CIRO hero — mobil
rep('<div class="zc-hero"><div class="l">Toplam etki ciro · dönem</div><div class="n">${kisa(toplamCiro)}</div></div>',
    '<div class="zc-hero"><div class="l">Toplam etki ciro · dönem</div><div class="n">${kisa((d && d.toplam_etki_ciro != null) ? d.toplam_etki_ciro : toplamCiro)}</div></div>',
    "ciro-hero-mobil")

if n == 0:
    print("[skip] bu dosyada anchor yok"); sys.exit(0)
open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_R1B (%s) — %d duzeltme" % (F, n))
