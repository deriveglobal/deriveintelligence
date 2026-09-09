#!/usr/bin/env python3
# KDV_CHIP_V1 — finans.html: her ₺ karta KDV bazi etiketi. Grid = KDVMAP (key->baz); Karlilik basligi = not.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/finans.html"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
if "KDV_CHIP_V1" in src:
    print("SKIP (zaten var)"); sys.exit(0)

reps = [
 # 1) GRIDMAP'ten sonra KDVMAP ekle
 (" 'Bağlı Sermaye Oranı':F=>pct(F.bagli_sermaye_pct)\n};",
  " 'Bağlı Sermaye Oranı':F=>pct(F.bagli_sermaye_pct)\n};\n"
  "const KDVMAP={ /* KDV_CHIP_V1 */\n"
  " 'Ticari Alacaklar':'KDV dahil','Stoklar · lastik':'KDV hariç','Ticari Borçlar':'KDV dahil',\n"
  " 'Net Satış · lastik işi':'KDV hariç','SMM (satılan malın maliyeti)':'KDV hariç','Brüt Marj':'KDV hariç · oran',\n"
  " 'DSO · tahsilat süresi':'KDV-tutarlı (bakiye net\\'e çekildi)','DIO · stok süresi':'KDV hariç','DPO · ödeme süresi':'KDV-tutarlı (bakiye net\\'e çekildi)',\n"
  " 'CCC · nakit döngüsü':'KDV-tutarlı','Ticari Sermaye (TWC)':'bakiye KDV dahil · stok hariç','Bağlı Sermaye Oranı':'oran'\n"
  "};"),
 # 2) renderGrid meta'ya KDV satiri (Nasil'dan sonra)
 ('<div class="r"><span class="t">Nasıl</span><span class="x num">${esc(m.nasil)}</span></div>',
  '<div class="r"><span class="t">Nasıl</span><span class="x num">${esc(m.nasil)}</span></div>\n'
  '    ${KDVMAP[m.k]?`<div class="r"><span class="t">KDV</span><span class="x">${esc(KDVMAP[m.k])}</span></div>`:\'\'}'),
 # 3) Karlilik basligina KDV notu
 ('<h2 class="sec"><span class="sn">A</span>Kârlılık metrikleri — her biri kendini anlatır</h2>',
  '<h2 class="sec"><span class="sn">A</span>Kârlılık metrikleri — her biri kendini anlatır <span style="color:var(--ink3);font-weight:400;text-transform:none;letter-spacing:0">· tümü KDV hariç</span></h2>'),
]
for old, new in reps:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}) for: {old[:60]!r}"
bak = PATH + ".bak_kdvchip_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
for old, new in reps: src = src.replace(old, new)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: KDV chip etiketleri eklendi")
print("KDV_CHIP_V1:", src.count("KDV_CHIP_V1"), "| KDVMAP:", src.count("KDVMAP"))
