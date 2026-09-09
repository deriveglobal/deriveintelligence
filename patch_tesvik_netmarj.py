#!/usr/bin/env python3
# FINANS_TESVIK_NETMARJ_V1 — "Net Marj (teşvik sonrası)" kartini bloklu->CANLI: gerceklesen net marj.
# = brut_marj_pct + kazanilan_tesvik/ciro (yalniz markalardan, chip'le tutarli). Saf CLIENT: FIN alanlarindan hesap, server yok.
# Kod formulu (ana oda 25460): (ciro-smm+prim)/ciro = brut marj + prim/ciro. tier (kesin_net) beklemez.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/finans.html"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()

if "FINANS_TESVIK_NETMARJ_V1" in src:
    print("SKIP (zaten var)"); sys.exit(0)

reps = [
 # (1) kart: bloklu -> canli, id=g2NetMarj, Nasil/Donem/Neden guncel
 ('         <div class="m"><span class="stat mid"></span><div class="row1"><span class="k">Net Marj (teşvik sonrası)</span><span class="badge prov">açık</span></div>\n'
  '           <div class="v num">—</div><div class="plain">Teşvikler dâhil gerçek net marj.</div>\n'
  '           <div class="meta"><div class="r"><span class="t">Nasıl</span><span class="x num">kesin_net_marj_pct · bi_marj_atom</span></div>\n'
  '             <div class="r"><span class="t">Dönem</span><span class="x">teşvik çatalı GÖMÜLMEDİ</span></div>\n'
  '             <div class="r why"><span class="t">Neden</span><span class="x">Kararlar net üzerinden verilmeli; açık kalem.</span></div></div></div>',
  '         <div class="m"><span class="stat ok"></span><div class="row1"><span class="k">Net Marj (teşvik sonrası)</span><span class="badge live">canlı</span></div>\n'
  '           <div class="v num" id="g2NetMarj">—</div><div class="plain">Teşvikler dâhil gerçekleşen net marj (seçili dönem).</div>\n'
  '           <div class="meta"><div class="r"><span class="t">Nasıl</span><span class="x num">brüt marj + kazanılan teşvik ÷ ciro · yalnız markalardan</span></div>\n'
  '             <div class="r"><span class="t">Dönem</span><span class="x">son 12 ay</span></div>\n'
  '             <div class="r why"><span class="t">Neden</span><span class="x">Kararlar net üzerinden — gerçekleşen (tier tahmini değil).</span></div></div></div> /* FINANS_TESVIK_NETMARJ_V1 */'),
 # (2) .then: g2Tesvik'ten sonra g2NetMarj hesabi
 ("       _setSmall('g2Tesvik',(tv.tutar==null?'—':fmtM(tv.tutar)),'M ₺'); /* FINANS_TESVIK_CHIP_V1 */",
  "       _setSmall('g2Tesvik',(tv.tutar==null?'—':fmtM(tv.tutar)),'M ₺'); /* FINANS_TESVIK_CHIP_V1 */\n"
  "       {const _nm=(FIN.brut_marj_pct!=null&&tv.tutar!=null&&FIN.net_satis_lastik)?(Number(FIN.brut_marj_pct)+Number(tv.tutar)/Number(FIN.net_satis_lastik)*100):null;_set('g2NetMarj',(_nm==null?'—':pct(Math.round(_nm*10)/10)));} /* FINANS_TESVIK_NETMARJ_V1 */"),
 # (3) DONEM dongusune g2NetMarj ekle
 (",'g2Tesvik'].forEach(id=>{",
  ",'g2Tesvik','g2NetMarj'].forEach(id=>{"),
]
for old, new in reps:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}) for: {old[:70]!r}"

bak = PATH + ".bak_netmarj_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
for old, new in reps:
    src = src.replace(old, new)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: 3 replace uygulandi")
print("FINANS_TESVIK_NETMARJ_V1 marker:", src.count("FINANS_TESVIK_NETMARJ_V1"), "| g2NetMarj:", src.count("g2NetMarj"), "| kalan acik badge('GÖMÜLMEDİ'):", src.count("GÖMÜLMEDİ"))
