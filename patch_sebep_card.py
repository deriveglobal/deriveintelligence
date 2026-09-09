#!/usr/bin/env python3
# OMURGA 51b (v2, girinti-toleranslı) — drag'in ÜSTÜNE sebep anlatısı + kök-neden tıkla-cevapla
import re, sys
F="shells/bi.js"; s=open(F,encoding="utf-8").read()
if "_markaSebepCiz" in s:
    print("  ⏭ zaten var"); sys.exit(0)

# 1) Çağrı: "_markaDragCiz(det, mk);" hemen öncesine sebep çağrısı (aynı girinti)
m=re.search(r"^([ \t]*)_markaDragCiz\(det, mk\);", s, re.M)
if not m:
    print("  ❌ çağrı çapası yok"); sys.exit(1)
ind=m.group(1)
s=s[:m.start()] + f"{ind}_markaSebepCiz(det, mk);\n" + s[m.start():]

# 2) Fonksiyon tanımı: "async function _markaDragCiz(det, mk){" öncesine ekle (aynı girinti)
m2=re.search(r"^([ \t]*)async function _markaDragCiz\(det, mk\)\{", s, re.M)
if not m2:
    print("  ❌ fonksiyon çapası yok"); sys.exit(1)
I=m2.group(1)
fns=(
f'{I}async function _markaSebepCiz(det, mk){{\n'
f'{I}  var box=document.createElement("div"); det.appendChild(box);\n'
f'{I}  var d={{}};\n'
f'{I}  try{{ var r=await fetch("/api/bi/finans-marka-sebep?marka="+encodeURIComponent(mk),{{credentials:"same-origin"}}); d=await r.json(); }}catch(e){{ return; }}\n'
f'{I}  if(!d || d.error || !d.anlati) return;\n'
f'{I}  var gr = d.guven==="kesin" ? "var(--tx-1)" : (d.guven==="belirsiz" ? "var(--kirmizi)" : "var(--tx-2)");\n'
f'{I}  var h="<div style=\\"margin-top:12px;border-top:0.5px solid var(--cizgi);padding-top:10px\\">"\n'
f'{I}    + "<div style=\\"font-size:12px;font-weight:600;margin-bottom:6px\\">\U0001f4a1 SEBEP <span style=\\"font-weight:400;color:"+gr+"\\">("+esc(String(d.guven||""))+")</span></div>"\n'
f'{I}    + "<div style=\\"font-size:12px;line-height:1.55;color:var(--tx-1)\\">"+esc(String(d.anlati))+"</div>";\n'
f'{I}  if(d.oneri) h+="<div style=\\"font-size:12px;line-height:1.5;color:var(--tx-2);margin-top:6px\\">"+esc(String(d.oneri))+"</div>";\n'
f'{I}  if(d.soru){{\n'
f'{I}    h+="<div id=\\"sebep-soru-kutu\\" style=\\"margin-top:10px;padding:9px;border:0.5px solid var(--cizgi-g);border-radius:8px\\">"\n'
f'{I}      +"<div style=\\"font-size:11px;color:var(--tx-2);margin-bottom:7px\\">\U0001f393 "+esc(String(d.soru.soru))+"</div>"\n'
f'{I}      +"<div id=\\"sebep-secenek\\" style=\\"display:flex;flex-wrap:wrap;gap:6px\\"></div></div>";\n'
f'{I}  }}\n'
f'{I}  h+="</div>"; box.innerHTML=h;\n'
f'{I}  if(d.soru){{\n'
f'{I}    var wrap=box.querySelector("#sebep-secenek"); var ops=d.soru.secenekler||[];\n'
f'{I}    ops.forEach(function(op){{\n'
f'{I}      var b=document.createElement("button"); b.textContent=op;\n'
f'{I}      b.style.cssText="font-size:11px;padding:4px 9px;border-radius:7px;cursor:pointer;border:0.5px solid var(--cizgi-g);background:transparent;color:var(--tx-1)";\n'
f'{I}      b.addEventListener("click",function(){{ _sebepCevapla(box, d.soru.id, op); }});\n'
f'{I}      wrap.appendChild(b);\n'
f'{I}    }});\n'
f'{I}  }}\n'
f'{I}}}\n'
f'{I}async function _sebepCevapla(box, id, cevap){{\n'
f'{I}  var el=box.querySelector("#sebep-soru-kutu");\n'
f'{I}  if(el) el.innerHTML="<div style=\\"font-size:11px;color:var(--tx-2)\\">… kaydediliyor</div>";\n'
f'{I}  try{{\n'
f'{I}    var r=await fetch("/api/bi/sistem-soru-cevap",{{method:"POST",credentials:"same-origin",headers:{{"Content-Type":"application/json"}},body:JSON.stringify({{id:id,cevap:cevap}})}});\n'
f'{I}    var d=await r.json();\n'
f'{I}    if(el) el.innerHTML="<div style=\\"font-size:11px;color:var(--tx-2)\\">\U0001f393 "+esc(String(d.mesaj||"Öğrendim."))+"</div>";\n'
f'{I}  }}catch(e){{ if(el) el.innerHTML="<div style=\\"font-size:11px;color:var(--kirmizi)\\">kaydedilemedi</div>"; }}\n'
f'{I}}}\n'
)
s=s[:m2.start()] + fns + s[m2.start():]
open(F,"w",encoding="utf-8").write(s)
print("  ✅ _markaSebepCiz + _sebepCevapla eklendi (girinti "+str(len(I))+" boşluk), çağrı drag'ten önce")
