#!/usr/bin/env python3
# FINANS_TESVIK_CHIP_V1 — Kârlılık görünümüne "Kazanılan Teşvik · markalardan" kartı (id=g2Tesvik).
# Statik kart; .then'de oda.tesvik.tutar ile dolar; DÖNEM etiketi mevcut _WLBL döngüsüne katılır (seçili döneme uyar).
# 4 replace, idempotent, .bak, count==1 assert, node --check (deploy scriptinde).
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/finans.html"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()

if "FINANS_TESVIK_CHIP_V1" in src:
    print("SKIP (zaten var)"); sys.exit(0)

reps = [
 # (1) Kârlılık grid'ine kart ekle — Fiyat sızıntısı ile Net Marj(teşvik sonrası) arasına
 ('             <div class="r why"><span class="t">Neden</span><span class="x">Fiyat düzeltmesiyle geri kazanılabilir.</span></div></div></div>\n'
  '         <div class="m"><span class="stat mid"></span><div class="row1"><span class="k">Net Marj (teşvik sonrası)</span>',
  '             <div class="r why"><span class="t">Neden</span><span class="x">Fiyat düzeltmesiyle geri kazanılabilir.</span></div></div></div>\n'
  '         <div class="m"><span class="stat ok"></span><div class="row1"><span class="k">Kazanılan Teşvik · markalardan</span><span class="badge live">canlı</span></div>\n'
  '           <div class="v num" id="g2Tesvik">— <small>M ₺</small></div><div class="plain">Brisa ve Otomotiv Lastikleri Tevzi (Continental) gibi tedarikçilerin verdiği destek + tüketici primi — hakedilip faturalanan tutar (seçili dönem).</div>\n'
  '           <div class="meta"><div class="r"><span class="t">Nasıl</span><span class="x num">SUM(satir_tutar) · DESTEK BEDELİ + TÜKETİCİ PRİM · yalnız muhatap = TEDARİKÇİ</span></div>\n'
  '             <div class="r"><span class="t">Dönem</span><span class="x">son 12 ay</span></div>\n'
  '             <div class="r why"><span class="t">Neden</span><span class="x">Markalardan gelen ek gelir — efektif marjı artırır.</span></div></div></div>\n'
  '         <div class="m"><span class="stat mid"></span><div class="row1"><span class="k">Net Marj (teşvik sonrası)</span>'),
 # (2) .then destructuring — tv=oda.tesvik ekle
 ('       const sz=oda.sizinti||{},ot=(oda.gecikmis||{}).olculen||{},ol=(oda.stok||{}).olu||{},sp=(oda.stok||{}).siparis||{};',
  '       const sz=oda.sizinti||{},ot=(oda.gecikmis||{}).olculen||{},ol=(oda.stok||{}).olu||{},sp=(oda.stok||{}).siparis||{},tv=oda.tesvik||{}; /* FINANS_TESVIK_CHIP_V1 */'),
 # (3) g2Tesvik degerini doldur (gOluStok'tan sonra)
 ('       _setSmall(\'gOluStok\',(ol.deger==null?\'—\':fmtM(ol.deger)),\'M ₺\');',
  '       _setSmall(\'gOluStok\',(ol.deger==null?\'—\':fmtM(ol.deger)),\'M ₺\');\n'
  '       _setSmall(\'g2Tesvik\',(tv.tutar==null?\'—\':fmtM(tv.tutar)),\'M ₺\'); /* FINANS_TESVIK_CHIP_V1 */'),
 # (4) DÖNEM-guncelleme dongusune g2Tesvik ekle
 ("['g2NetSatis','g2Smm','g2BrutKar','g2BrutMarj','gSizinti'].forEach(id=>{",
  "['g2NetSatis','g2Smm','g2BrutKar','g2BrutMarj','gSizinti','g2Tesvik'].forEach(id=>{"),
]
for old, new in reps:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}) for: {old[:70]!r}"

bak = PATH + ".bak_tesvik_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
for old, new in reps:
    src = src.replace(old, new)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: 4 replace uygulandi")
print("FINANS_TESVIK_CHIP_V1 marker:", src.count("FINANS_TESVIK_CHIP_V1"), "| g2Tesvik:", src.count("g2Tesvik"))
