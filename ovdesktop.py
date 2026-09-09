#!/usr/bin/env python3
# ODEME_VADELERI_DESKTOP_V1 — kokpit.html'e "Vade · Müşteri↔Tedarikçi" paneli ekler.
# /api/bi/odeme-vadeleri: kova bazlı dağılım + ağırlıklı ort gün + finansman farkı.
# Gruplu bar (.brow/.track/.bar), müşteri mavi (--blu) / tedarikçi amber (--amb). Idempotent.
# shells/kokpit.html statik dosya; docker build + up gerekir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "kokpit.html"
s = read(FP)
if "ODEME_VADELERI_DESKTOP_V1" in s:
    print("ov-desktop: already present, skip"); print("DONE."); raise SystemExit

# (1) ovInto() fonksiyonunu LAYOUT bölümünden önce ekle
a1 = "/* ---- LAYOUT (buildAll: fetch sonrasi) ---- */"
fn = r'''/* ---- ODEME_VADELERI_DESKTOP_V1 — Vade: Müşteri tahsilat vs Tedarikçi ödeme ---- */
async function ovInto(body){
  body.innerHTML='<div style="color:var(--mut);font-family:var(--mono);font-size:11px">yükleniyor…</div>';
  let d=null; try{ d=await (await fetch('/api/bi/odeme-vadeleri',{credentials:'same-origin'})).json(); }catch(e){ d=null; }
  if(!d||d.error||!d.musteri||!d.tedarikci){ body.innerHTML='<div style="color:var(--ink2);font-size:11.5px">Vade verisi canlı bağlanır — müşteri/tedarikçi ödeme koşulu.</div>'; return; }
  const g=v=>Math.round(v||0), P=v=>(v==null?'—':Number(v).toLocaleString("tr-TR",{maximumFractionDigits:1})+'%');
  const mg=d.musteri.ort_gun, tg=d.tedarikci.ort_gun, fk=d.fark_gun;
  const gc=fk>0?'var(--red)':fk<0?'var(--grn)':'var(--ink2)';
  const gtxt=fk>0?('Müşteriler '+Math.abs(fk)+' gün geç ödüyor — farkı sen finanse ediyorsun')
    :fk<0?('Tedarikçiler seni '+Math.abs(fk)+' gün finanse ediyor — nakit lehine')
    :'Vadeler dengeli';
  const kv=d.kovalar||[];
  const grup=(arr,col)=>kv.map((k,i)=>{const p=(arr[i]&&arr[i].pct)||0;
    return '<div class="brow"><span class="nm" title="'+k+'">'+k+'</span><span class="track"><span class="bar" style="width:'+Math.max(2,Math.min(100,p))+'%;background:'+col+';box-shadow:0 0 8px '+col+'55"></span></span><span class="v">'+P(p)+'</span></div>';}).join("");
  body.innerHTML=
    '<div style="display:flex;gap:14px;margin-bottom:8px">'
    +'<div><div style="font-size:9.5px;letter-spacing:.6px;text-transform:uppercase;color:var(--blu)">● Müşteri tahsilat</div><div class="num" style="font-size:22px;font-weight:600;color:var(--ink)">'+g(mg)+'<small style="font-size:11px;color:var(--ink2)"> gün</small></div></div>'
    +'<div><div style="font-size:9.5px;letter-spacing:.6px;text-transform:uppercase;color:var(--amb)">● Tedarikçi ödeme</div><div class="num" style="font-size:22px;font-weight:600;color:var(--ink)">'+g(tg)+'<small style="font-size:11px;color:var(--ink2)"> gün</small></div></div>'
    +'<div style="flex:1"><div style="font-size:9.5px;letter-spacing:.6px;text-transform:uppercase;color:var(--mut)">Finansman farkı</div><div class="num" style="font-size:22px;font-weight:600;color:'+gc+'">'+(fk>0?'+':'')+g(fk)+'<small style="font-size:11px;color:var(--ink2)"> gün</small></div></div>'
    +'</div>'
    +'<div style="font-size:11px;color:'+gc+';font-family:var(--mono);margin-bottom:9px">'+gtxt+'</div>'
    +'<div style="font-size:9.5px;letter-spacing:.5px;text-transform:uppercase;color:var(--blu);margin:2px 0 3px">Müşteri tahsilat dağılımı</div>'
    +grup(d.musteri.dagilim,'var(--blu)')
    +'<div style="font-size:9.5px;letter-spacing:.5px;text-transform:uppercase;color:var(--amb);margin:9px 0 3px">Tedarikçi ödeme dağılımı</div>'
    +grup(d.tedarikci.dagilim,'var(--amb)')
    +'<div style="margin-top:8px;font-size:10px;color:var(--mut);font-family:var(--mono)">%=tutar payı · ort gün=ağırlıklı ortalama (12 ay)</div>';
}
'''
assert s.count(a1) == 1, "LAYOUT anchor"
s = s.replace(a1, fn + a1, 1)

# (2) buildAll() içine panel çağrısı ekle (piyasaInto'dan sonra)
a2 = ('  piyasaInto(panel("piy","Piyasa Radar",866,516,320,210,"canlı"));\n'
      '}')
n2 = ('  piyasaInto(panel("piy","Piyasa Radar",866,516,320,210,"canlı"));\n'
      '  ovInto(panel("ovd","Vade · Müşteri↔Tedarikçi",12,872,820,250,"buckets · ort gün"));\n'
      '}')
assert s.count(a2) == 1, "buildAll anchor"
s = s.replace(a2, n2, 1)

write(FP, s)
print("ov-desktop: ovInto + buildAll paneli eklendi")
print("DONE.")
