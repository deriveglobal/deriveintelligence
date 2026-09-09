#!/usr/bin/env python3
# OMURGA 44 — marka drill'e "KÂR SIZINTISI SKU'LARI" bölümü (finans-marka-drag). bi.js UI.
import sys, subprocess
BIJS='/opt/krb-assessment/shells/bi.js'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
b=rd(BIJS)
if '_markaDragCiz' in b:
    print('  ⏭ zaten yamalı'); sys.exit(0)

# 1) footer notu düzelt (güncel→dönem-eşleşmeli)
NOTE_OLD = "marj brüt, güncel maliyet bazı</div>';"
NOTE_NEW = "marj brüt, dönem-eşleşmeli maliyet (atom)</div>';"

# 2) det.innerHTML sonrası drag çağır + fonksiyon
CALL_OLD = "    det.innerHTML=hh; det.setAttribute('data-yuklendi',String(_markaAy));\n  }"
CALL_NEW = r'''    det.innerHTML=hh; det.setAttribute('data-yuklendi',String(_markaAy));
    _markaDragCiz(det, mk);
  }

  async function _markaDragCiz(det, mk){
    var box=document.createElement("div"); det.appendChild(box);
    var d={satirlar:[]};
    try{ var r=await fetch("/api/bi/finans-marka-drag?marka="+encodeURIComponent(mk)+"&ay="+_markaAy,{credentials:"same-origin"}); d=await r.json(); if(d.error)return; }catch(e){ return; }
    var rows=d.satirlar||[]; if(!rows.length) return;
    function _tl(v){ return v==null?"—":Number(v).toLocaleString("tr-TR"); }
    var h="<div style=\"margin-top:12px;border-top:0.5px solid var(--cizgi);padding-top:10px\">"
      + "<div style=\"font-size:12px;font-weight:600;margin-bottom:6px\">🔻 KÂR SIZINTISI SKU’LARI <span style=\"font-weight:400;color:var(--tx-2)\">(marka marjı %"+d.marka_marj_pct+")</span></div>";
    rows.forEach(function(x){
      var neg = x.marj_pct!=null && x.marj_pct<0;
      h += "<div style=\"padding:5px 0;border-top:0.5px solid var(--cizgi)\">"
        + "<div style=\"display:flex;justify-content:space-between;font-size:12px\"><span><b>"+esc(x.ebat)+"</b> · "+_tl(x.adet)+" adet</span>"
        + "<span style=\"color:"+(neg?"var(--kirmizi)":"var(--tx-1)")+"\">"+_tl(x.fiyat)+" fiyat · <b>%"+(x.marj_pct==null?"—":x.marj_pct)+"</b></span></div>"
        + "<div style=\"font-size:11px;color:var(--tx-2);margin-top:2px\">maliyet "+_tl(x.maliyet)+" · marka ort’a çıksa +"+_M(x.ek_kar)+" · %15 için <b>+%"+(x.gereken_zam==null?"—":x.gereken_zam)+"</b> zam"+(x.piyasa?" · piyasa(perakende) "+_tl(x.piyasa):" · piyasa yok")+"</div></div>";
    });
    h += "<div style=\"font-size:10px;color:var(--tx-3);margin-top:5px\">Piyasa=perakende, bizim=bayi (yön sinyali). Zam alanı varsa fiyatı güncelle.</div></div>";
    box.innerHTML=h;
  }'''

for name, old in [('NOTE',NOTE_OLD),('CALL',CALL_OLD)]:
    c=b.count(old)
    if c!=1:
        print(f'  ✗ {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
b=b.replace(NOTE_OLD,NOTE_NEW,1).replace(CALL_OLD,CALL_NEW,1)
wr(BIJS,b)
print('  ✅ drag kartı + not düzeltme')

r=subprocess.run(['node','--check',BIJS],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
b2=rd(BIJS)
print('  drag fn :', 'async function _markaDragCiz' in b2)
print('  çağrı   :', '_markaDragCiz(det, mk);' in b2)
print('\n  ✅ YAMA TAMAM — docker build; drill\'de kâr sızıntısı SKU\'ları görünür')
