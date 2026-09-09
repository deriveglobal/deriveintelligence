#!/usr/bin/env python3
# ANALIZ_FN_MAP_V1 — sistem haritasi recete 1 (vade makasi) + 4 (marka sagligi) curated fonksiyon cagri talimati.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
if "vade_makasi(tenant_id) fonksiyonunu" in src:
    print("SKIP (zaten var)"); sys.exit(0)

reps = [
 (r'''makasin yonu degistiyse isletme sermayesi rahatladi ya da sikisti.''',
  r'''makasin yonu degistiyse isletme sermayesi rahatladi ya da sikisti. Elle kurma; vade_makasi(tenant_id) fonksiyonunu cagir -> satis_vade_12, alim_vade_12, makas_12, satis_vade_onceki, alim_vade_onceki, makas_onceki, kayma (kanonik ₺-agirlikli). makas_12 negatif = tedarikci seni finanse ediyor; kayma negatif = makas lehine dondu.'''),
 (r'''Gecisgenlik, sizinti, olu stok ve on-siparis ayni markayi isaret ediyorsa tesaduf degildir; birlestir ve tek kok-neden olarak anlat.''',
  r'''Gecisgenlik, sizinti, olu stok ve on-siparis ayni markayi isaret ediyorsa tesaduf degildir; birlestir ve tek kok-neden olarak anlat. Bunun icin marka_saglik(tenant_id) fonksiyonunu cagir -> her marka icin brut_kar_m, sizinti_m, olu_stok_m, gecisgenlik_fark, sorun_say. sorun_say>=2 olan marka birden fazla yerden kaniyor (ornek: hem maliyet-alti hem olu stok hem gecisgenlik sikismasi) -> tek kok-neden: o markaya asiri baglanma. Elle kurma.'''),
]
for old, new in reps:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}) for: {old[:50]!r}"
bak = PATH + ".bak_analizmap_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
for old, new in reps: src = src.replace(old, new)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: vade_makasi + marka_saglik cagri talimatlari eklendi")
print("marker:", src.count("vade_makasi(tenant_id) fonksiyonunu"), src.count("marka_saglik(tenant_id) fonksiyonunu"))
