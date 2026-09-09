#!/usr/bin/env python3
# FINANS_WIN_CLIENT_V1 — finans.html: zaman secici akis kartlarini pencereler (re-fetch ?win),
# 4 eksik metrik dolar (sizinti/olculen tahsilat/olu stok/siparis), akis DONEM etiketi secilen doneme guncellenir,
# bilanco+dongu daima anlik (ust seritte netlestirilir). count==1 her replace.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/finans.html"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
orig = src; changes = []
def apply(name, new, old):
    global src
    if new in src: changes.append(f"SKIP: {name}"); return
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}): {name}"
    src = src.replace(old, new); changes.append(f"OK: {name}")

# --- 4 placeholder kart: id + rozet(canli) + aciklama ---
apply("kart Sizinti",
  '<span class="badge live">canlı</span></div>\n           <div class="v num" id="gSizinti">— <small>M ₺</small></div><div class="plain">Maliyet-altı satılan lastiğin kaybettirdiği brüt kâr (seçili dönem).</div>',
  '<span class="badge prov">geçici</span></div>\n           <div class="v num">—</div><div class="plain">Fiyat sızıntısı — canlı kaynağa bağlanacak.</div>')
apply("kart Olculen",
  '<span class="k">Ölçülen tahsilat</span><span class="badge live">canlı</span></div>\n           <div class="v num" id="gOlculen">— <small>gün</small></div><div class="plain">Faturaların ortalama kaç günde ödendiği — ölçülen (bilanço DSO değil).</div>',
  '<span class="k">Ölçülen tahsilat</span><span class="badge live">canlı</span></div>\n           <div class="v num">—</div><div class="plain">Ölçülen tahsilat — canlı kaynağa bağlanacak.</div>')
apply("kart OluStok",
  '<span class="badge live">canlı</span></div>\n           <div class="v num" id="gOluStok">— <small>M ₺</small></div><div class="plain">90 gündür satış-çıkışı olmayan lastik — donmuş sermaye.</div>',
  '<span class="badge prov">tahmin</span></div>\n           <div class="v num">—</div><div class="plain">Ölü + yavaş stok — canlı kaynağa bağlanacak.</div>')
apply("kart Siparis",
  '<span class="badge live">canlı</span></div>\n           <div class="v num" id="gSiparis">— <small>M ₺</small></div><div class="plain">Yolda olan / bekleyen sipariş değeri — gelen sermaye.</div>',
  '<span class="badge prov">açık</span></div>\n           <div class="v num">—</div><div class="plain">Yolda olan / bekleyen sipariş değeri.</div>')

# --- loadFin(win) imza + ?win fetch ---
apply("loadFin imza", "function loadFin(win){win=win||'12';", "function loadFin(){")
apply("fetch ?win",
  "fetch('/api/bi/finans/oda?win='+encodeURIComponent(win),{headers:{'Accept':'application/json'},credentials:'same-origin'})",
  "fetch('/api/bi/finans/oda',{headers:{'Accept':'application/json'},credentials:'same-origin'})")

# --- .then: yeni metrikler + akis DONEM etiketi + strip senkron (FINANS_WIN_CLIENT_V1) ---
apply("then akis-doldur",
  """     applyFin(mapped);_rich(oda);setLive(true);
     try{ /* FINANS_WIN_CLIENT_V1 */
       const sz=oda.sizinti||{},ot=(oda.gecikmis||{}).olculen||{},ol=(oda.stok||{}).olu||{},sp=(oda.stok||{}).siparis||{};
       _setSmall('gSizinti',(sz.tutar==null?'—':fmtM(sz.tutar)),'M ₺');
       _setSmall('gOlculen',(ot.gun==null?'—':fmt0(ot.gun)),'gün');
       _setSmall('gOluStok',(ol.deger==null?'—':fmtM(ol.deger)),'M ₺');
       _setSmall('gSiparis',(sp.deger==null?'—':fmtM(sp.deger)),'M ₺');
       const _lbl=_WLBL[win]||win;
       ['g2NetSatis','g2Smm','g2BrutKar','g2BrutMarj','gSizinti'].forEach(id=>{const c=document.getElementById(id);if(!c)return;const card=c.closest('.m');if(!card)return;card.querySelectorAll('.meta .r').forEach(r=>{const t=r.querySelector('.t');if(t&&t.textContent.trim()==='Dönem'){const x=r.querySelector('.x');if(x)x.textContent=_lbl;}});});
       setWin(win);
     }catch(e){}
   })""",
  """     applyFin(mapped);_rich(oda);setLive(true);})""")

# --- secici -> re-fetch (loadFin) ---
apply("secici re-fetch",
  "_tc.querySelectorAll('button').forEach(x=>x.classList.remove('on'));b.classList.add('on');setWin(b.dataset.w);loadFin(b.dataset.w);};",
  "_tc.querySelectorAll('button').forEach(x=>x.classList.remove('on'));b.classList.add('on');setWin(b.dataset.w);};")

# --- ust serit: akis vs bilanco ayrimini netlestir ---
apply("strip not",
  "· <b>Akış</b> (ciro/marj/kâr/marka) seçili döneme göre · <b>Bilanço & döngü</b> (alacak/borç/stok/DSO/DIO/DPO/CCC) daima anlık</span>",
  "· nakit döngüsü daima 12-ay kaydırmalı + anlık</span>")

if src == orig: print("DEGISIKLIK YOK")
else:
    bak = PATH + ".bak_finansclient_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    with open(PATH, "w", encoding="utf-8") as f: f.write(src)
for c in changes: print(" ", c)
print("FINANS_WIN_CLIENT_V1 marker:", src.count("FINANS_WIN_CLIENT_V1"))
