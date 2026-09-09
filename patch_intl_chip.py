#!/usr/bin/env python3
# INTL_CHIP_V1 — finans.html grid kartlarina ULUSLARARASI finans terimi/anlami ("Terim" satiri).
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/finans.html"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
if "INTL_CHIP_V1" in src:
    print("SKIP (zaten var)"); sys.exit(0)

reps = [
 # 1) KDVMAP'ten sonra INTLMAP ekle
 (" 'CCC · nakit döngüsü':'KDV-tutarlı','Ticari Sermaye (TWC)':'bakiye KDV dahil · stok hariç','Bağlı Sermaye Oranı':'oran'\n};",
  " 'CCC · nakit döngüsü':'KDV-tutarlı','Ticari Sermaye (TWC)':'bakiye KDV dahil · stok hariç','Bağlı Sermaye Oranı':'oran'\n};\n"
  "const INTLMAP={ /* INTL_CHIP_V1 */\n"
  " 'Ticari Alacaklar':'Accounts Receivable (AR) — müşteri borcu',\n"
  " 'Stoklar · lastik':'Inventory — stok',\n"
  " 'Ticari Borçlar':'Accounts Payable (AP) — tedarikçi borcu',\n"
  " 'Net Satış · lastik işi':'Revenue / Net Sales — net ciro',\n"
  " 'SMM (satılan malın maliyeti)':'COGS — Cost of Goods Sold',\n"
  " 'Brüt Marj':'Gross Margin — brüt kâr ÷ satış',\n"
  " 'DSO · tahsilat süresi':'Days Sales Outstanding — tahsil hızı; düşük iyi',\n"
  " 'DIO · stok süresi':'Days Inventory Outstanding — stok hızı; düşük iyi',\n"
  " 'DPO · ödeme süresi':'Days Payable Outstanding — ödeme süresi; yüksek nakit lehine',\n"
  " 'CCC · nakit döngüsü':'Cash Conversion Cycle = DIO + DSO − DPO',\n"
  " 'Ticari Sermaye (TWC)':'Net / Trade Working Capital = AR + Stok − AP',\n"
  " 'Bağlı Sermaye Oranı':'Working Capital Intensity = TWC ÷ satış'\n"
  "};"),
 # 2) meta'ya "Terim" satiri (Nasil'dan ONCE)
 ('<div class="r"><span class="t">Nasıl</span><span class="x num">${esc(m.nasil)}</span></div>',
  '${INTLMAP[m.k]?`<div class="r"><span class="t">Terim</span><span class="x">${esc(INTLMAP[m.k])}</span></div>`:\'\'}\n'
  '    <div class="r"><span class="t">Nasıl</span><span class="x num">${esc(m.nasil)}</span></div>'),
]
for old, new in reps:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}) for: {old[:55]!r}"
bak = PATH + ".bak_intlchip_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
for old, new in reps: src = src.replace(old, new)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: INTL terim satiri eklendi")
print("INTL_CHIP_V1:", src.count("INTL_CHIP_V1"), "| INTLMAP:", src.count("INTLMAP"))
