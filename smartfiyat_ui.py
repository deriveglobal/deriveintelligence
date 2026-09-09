#!/usr/bin/env python3
# SMARTFIYAT_UI_V1 — Musteri kartina Akilli Fiyat (Seviye 2) + Musteri Skoru karti.
#  (A) Kart ustu MUSTERI SKORU karti: 0-100 skor + harf notu + bilesim barlari (Odeme/Hacim/Sadakat/Risk)
#      + vade onerisi. "i" tiklayinca skorun grading aciklamasi acilir.  (/api/bi/musteri-skor)
#  (B) "Son Alimlar" tablosuna ONERILEN sutunu — musterinin aldigi her SKU icin oneri (satir-ici).
#      (/api/bi/musteri-fiyat-liste toplu)
#  (C) "Akilli Fiyat Onerisi" arama modulu — herhangi bir ebat sorgula -> oneri + vade-fiyat menusu.
# Sadece manager/admin + ERP-bagli musteri. saha.js. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "SMARTFIYAT_UI_V1" in s:
    print("smartfiyat: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTPRICE_V2" not in s or True  # sunucu tarafi ayri

# (1) Fonksiyonlar — musteriDetayModal'dan ONCE
A_fn = "function musteriDetayModal(m) {\n  const [dl, dc] = DURUM_ETIKET[m.durum] || [\"\", \"#999\"];"
assert s.count(A_fn) == 1, "musteriDetayModal anchor"
FN = r'''/* SMARTFIYAT_UI_V1 — Musteri Skoru + Akilli Fiyat */
function _foGrade(x){ if(x==null)return["—","#64748b"]; if(x>=80)return["A · Güçlü","#16a34a"]; if(x>=65)return["B · İyi","#16a34a"]; if(x>=50)return["C · Orta","#d97706"]; if(x>=35)return["D · Zayıf","#dc2626"]; return["E · Riskli","#dc2626"]; }
function _foBar(l,w,v,col){ return '<div style="display:flex;align-items:center;gap:6px;margin:2px 0"><span style="flex:0 0 108px;font-size:10px;color:#64748b">'+l+' <span style="color:#cbd5e1">'+w+'</span></span><span style="flex:1;height:6px;background:#eef2f7;border-radius:3px;overflow:hidden"><i style="display:block;height:100%;width:'+Math.max(2,Math.min(100,v||0))+'%;background:'+col+'"></i></span><span style="flex:0 0 24px;font-size:10px;text-align:right;color:#64748b">'+(v!=null?v:"—")+'</span></div>'; }
function _foScoreCard(skor,bil,vade_oneri){
  const gg=_foGrade(skor), col=gg[1]; bil=bil||{};
  const bars=_foBar("Ödeme","%35",bil.odeme,col)+_foBar("Hacim","%25",bil.hacim,col)+_foBar("Sadakat","%20",bil.sadakat,col)+_foBar("Risk","%20",bil.risk,col);
  return '<div class="fo-card" style="border:1px solid #e2e8f0;border-radius:12px;padding:12px;background:#fff">'
    +'<div style="display:flex;align-items:center;gap:12px">'
    +'<div style="flex:0 0 auto;text-align:center"><div style="font-family:monospace;font-size:30px;font-weight:800;color:'+col+';line-height:1">'+(skor!=null?skor:"—")+'</div><div style="font-size:9px;color:#94a3b8;letter-spacing:.3px">MÜŞTERİ SKORU</div></div>'
    +'<div style="flex:1;min-width:0"><div style="display:flex;align-items:center;gap:6px"><b style="color:'+col+'">'+gg[0]+'</b><span class="fo-skor-i" style="cursor:pointer;color:#94a3b8;border:1px solid #e2e8f0;border-radius:50%;width:16px;height:16px;display:inline-flex;align-items:center;justify-content:center;font-size:10px">i</span></div><div style="margin-top:4px">'+bars+'</div></div>'
    +'</div>'
    +(vade_oneri?'<div style="font-size:11px;color:#0369a1;margin-top:8px;border-top:1px solid #f1f5f9;padding-top:6px">💡 Vade önerisi: <b>'+esc(vade_oneri)+'</b></div>':'')
    +'<div class="fo-skor-ac" style="display:none;font-size:11px;color:#475569;margin-top:8px;background:#f1f5f9;border-radius:8px;padding:8px;line-height:1.55">Skor = <b>Ödeme %35 + Hacim %25 + Sadakat %20 + Risk %20</b>, tüm müşteri tabanına göre.<br>• <b>Ödeme:</b> tahsilat hızı + gecikme oranı.<br>• <b>Hacim:</b> yıllık ciro büyüklüğü.<br>• <b>Sadakat:</b> alım sıklığı + ürün çeşitliliği.<br>• <b>Risk:</b> net açık pozisyon / kredi limiti.</div>'
    +'</div>';
}
function _foBindSkorI(root){ (root||document).querySelectorAll(".fo-skor-i").forEach(function(b){ if(b._bound)return; b._bound=1; b.addEventListener("click",function(){ var card=b.closest(".fo-card"); var ac=card&&card.querySelector(".fo-skor-ac"); if(ac)ac.style.display=(ac.style.display==="none"?"block":"none"); }); }); }
async function _foSkor(m){
  const el=document.getElementById("mus-skor"); if(!el||!m||!m.musteri_kodu) return;
  el.innerHTML='<div style="color:#94a3b8;font-size:13px;padding:6px">Skor hesaplanıyor…</div>';
  try{
    const d=await api("/api/bi/musteri-skor?musteri="+encodeURIComponent(m.musteri_kodu));
    if(d.error||d.skor==null){ el.innerHTML='<div style="font-size:12px;color:#94a3b8;font-style:italic">Skor için yeterli ERP geçmişi yok.</div>'; return; }
    el.innerHTML=_foScoreCard(d.skor,d.bilesenler,d.vade_oneri);
    _foBindSkorI(el);
  }catch(e){ el.innerHTML='<div style="font-size:12px;color:#94a3b8">Skor yüklenemedi.</div>'; }
}
async function _foRecent(m){
  if(!m||!m.musteri_kodu||!(["manager","admin"].indexOf(S.role)>-1)) return;
  const cells=Array.prototype.slice.call(document.querySelectorAll("[data-fo-oneri]"));
  const kalems=[]; cells.forEach(function(c){var k=c.getAttribute("data-fo-oneri"); if(k&&kalems.indexOf(k)<0)kalems.push(k);});
  if(!kalems.length) return;
  try{
    const d=await api("/api/bi/musteri-fiyat-liste?musteri="+encodeURIComponent(m.musteri_kodu)+"&kalemler="+encodeURIComponent(kalems.join(",")));
    const DURc={LIFT:"#16a34a",WATCH:"#b45309",UYGUN:"#0369a1",YENI:"#7c3aed"};
    cells.forEach(function(c){var k=c.getAttribute("data-fo-oneri");var r=d.kalemler&&d.kalemler[k];
      if(r&&r.oneri!=null){c.innerHTML='<b style="color:'+(DURc[r.durum]||"#0f172a")+'" title="'+(r.durum||"")+'">'+Number(r.oneri).toLocaleString("tr-TR")+'</b>';}
      else c.textContent="—";});
  }catch(e){}
}
function _foFiyatInit(m){
  const inp=document.getElementById("fo-q"); if(!inp||!m||!m.musteri_kodu) return;
  let _t=null;
  const run=async function(){
    const q=inp.value.trim(); const box=document.getElementById("fo-sonuc"); if(!box) return;
    if(q.replace(/[^0-9]/g,"").length<2){box.innerHTML="";return;}
    try{
      const res=await api("/api/bi/ebat-ara?q="+encodeURIComponent(q)); const sonuclar=res.sonuclar||[];
      if(!sonuclar.length){box.innerHTML='<div style="color:#94a3b8;font-size:13px;padding:6px">Sonuç yok.</div>';return;}
      box.innerHTML=sonuclar.map(function(x){return '<button class="fo-pick" data-kalem="'+esc(x.kalem_kodu||"")+'" data-ad="'+esc(x.ad||"")+'" style="display:flex;justify-content:space-between;gap:8px;width:100%;box-sizing:border-box;text-align:left;padding:10px;margin-bottom:4px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;color:#0f172a;cursor:pointer"><span style="min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">'+esc(x.ad||"")+'</span><span style="color:#64748b;font-size:12px;white-space:nowrap">'+(x.adet!=null?Number(x.adet).toLocaleString("tr-TR")+" ad":"")+'</span></button>';}).join("");
      box.querySelectorAll(".fo-pick").forEach(function(b){b.addEventListener("click",function(){ inp.value=b.dataset.ad; box.innerHTML=""; _foLoad(m,b.dataset.kalem); });});
    }catch(e){box.innerHTML='<div style="color:#dc2626;font-size:13px;padding:6px">Arama hatası.</div>';}
  };
  inp.addEventListener("input",function(){clearTimeout(_t);_t=setTimeout(run,220);});
}
async function _foLoad(m,kalem){
  const kart=document.getElementById("fo-kart"); if(!kart) return;
  const money=function(v){return v==null?"—":Number(v).toLocaleString("tr-TR",{maximumFractionDigits:0})+" ₺";};
  kart.innerHTML='<div style="color:#94a3b8;font-size:13px;padding:6px">Hesaplanıyor…</div>';
  try{
    const d=await api("/api/bi/musteri-fiyat-liste?musteri="+encodeURIComponent(m.musteri_kodu)+"&kalemler="+encodeURIComponent(kalem));
    const r=d.kalemler&&d.kalemler[kalem];
    if(!r||r.oneri==null){kart.innerHTML='<div style="color:#94a3b8;font-size:13px;padding:6px">Bu ürün için veri yok.</div>';return;}
    const DUR={LIFT:["⬆ Yükselt","#16a34a","#dcfce7"],WATCH:["👁 İzle","#b45309","#fef9c3"],UYGUN:["✓ Uygun","#0369a1","#e0f2fe"],YENI:["✦ Yeni","#7c3aed","#f3e8ff"]};
    const dd=DUR[r.durum]||["—","#64748b","#f1f5f9"]; const g=r.gercek;
    const vm=(r.vade_menu||[]).map(function(x){return '<div style="flex:1;text-align:center;background:#f8fafc;border-radius:6px;padding:5px 2px"><div style="font-size:9px;color:#94a3b8">'+(x.vade===0?"Peşin":x.vade+" gün")+'</div><div style="font-size:12px;font-weight:700">'+Number(x.fiyat).toLocaleString("tr-TR")+'</div></div>';}).join("");
    kart.innerHTML=
      '<div style="border:1px solid #e2e8f0;border-radius:12px;padding:12px;background:#fff">'
      +'<div style="font-weight:700;font-size:13px;margin-bottom:8px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">'+esc(r.ad||((r.marka||"")+" "+(r.ebat||"")))+'</div>'
      +'<div style="display:flex;gap:8px;margin-bottom:8px">'
      +'<div style="flex:1;background:#f8fafc;border-radius:8px;padding:8px 10px"><div style="font-size:10px;color:#64748b;text-transform:uppercase">Şu an ödediği</div><div style="font-size:16px;font-weight:700">'+(g!=null?money(g):"—")+'</div></div>'
      +'<div style="flex:1;background:'+dd[2]+';border-radius:8px;padding:8px 10px"><div style="font-size:10px;color:'+dd[1]+';text-transform:uppercase;font-weight:700">Önerilen '+dd[0]+'</div><div style="font-size:16px;font-weight:800;color:'+dd[1]+'">'+money(r.oneri)+'</div><div style="font-size:10px;color:#94a3b8">'+(r.marj_oneri!=null?"marj %"+r.marj_oneri:"")+'</div></div>'
      +'</div>'
      +'<div style="font-size:11px;color:#64748b;margin-bottom:6px">Pazar bandı: '+money(r.lo)+' – <b>'+money(r.med)+'</b> – '+money(r.hi)+' · maliyet '+money(r.repl_cost!=null?r.repl_cost:r.maliyet)+'</div>'
      +'<div style="font-size:10px;color:#64748b;text-transform:uppercase;margin:2px 0 3px">Vade–fiyat menüsü</div><div style="display:flex;gap:4px">'+vm+'</div>'
      +'</div>';
  }catch(e){kart.innerHTML='<div style="color:#dc2626;font-size:13px;padding:6px">Öneri yüklenemedi.</div>';}
}
'''
s = s.replace(A_fn, FN + A_fn, 1)

# (2) Skor karti + arama modulu — Finansal bolumunun etrafina
A_html = ('    <h4 class="bolum-baslik">\U0001f4b0 Finansal & Alımlar</h4>\n'
          '    <div id="mus-finansal" class="mini-durum">Yükleniyor…</div>')
assert s.count(A_html) == 1, "finansal anchor"
H_NEW = ('    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? \'<div id="mus-skor" style="margin:6px 0 10px"></div>\' : ""}\n'
         '    <h4 class="bolum-baslik">\U0001f4b0 Finansal & Alımlar</h4>\n'
         '    <div id="mus-finansal" class="mini-durum">Yükleniyor…</div>\n'
         '    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? `\n'
         '    <h4 class="bolum-baslik">\U0001f3af Akıllı Fiyat Önerisi <small style="font-weight:400;color:#94a3b8;font-size:11px">· başka ebat sorgula</small></h4>\n'
         '    <div id="mus-fiyat" style="margin:2px 0 6px">\n'
         '      <input id="fo-q" placeholder="Ebat ara: 385 65 22.5" autocomplete="off" style="width:100%;box-sizing:border-box;padding:10px;border:1px solid #cbd5e1;border-radius:8px;font-size:16px;background:#fff;color:#0f172a">\n'
         '      <div id="fo-sonuc" style="margin-top:6px"></div>\n'
         '      <div id="fo-kart" style="margin-top:10px"></div>\n'
         '    </div>` : ""}')
s = s.replace(A_html, H_NEW, 1)

# (3) Son Alimlar tablosu — ONERILEN sutunu (baslik)
A_th = '<th style="padding:3px 6px;text-align:right;font-weight:600">Birim ₺</th></tr></thead>'
assert s.count(A_th) == 1, "son_alimlar th anchor"
N_th = '<th style="padding:3px 6px;text-align:right;font-weight:600">Birim ₺</th>${["manager","admin"].includes(S.role)?\'<th style="padding:3px 6px;text-align:right;font-weight:600">Önerilen</th>\':\'\'}</tr></thead>'
s = s.replace(A_th, N_th, 1)

# (4) Son Alimlar tablosu — ONERILEN hucre (satir)
A_td = ('${a.birim_fiyat != null ? Number(a.birim_fiyat).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) : "—"}</td>\n'
        '          </tr>')
assert s.count(A_td) == 1, "son_alimlar td anchor"
N_td = ('${a.birim_fiyat != null ? Number(a.birim_fiyat).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) : "—"}</td>'
        '${["manager","admin"].includes(S.role)?`<td style="padding:3px 6px;text-align:right" data-fo-oneri="${esc(a.kalem_kodu||\'\')}">·</td>`:""}\n'
        '          </tr>')
s = s.replace(A_td, N_td, 1)

# (5) Finansal render sonrasi — recent oneri doldur
A_rn = "      el.innerHTML = render(d);"
assert s.count(A_rn) == 1, "render(d) anchor"
s = s.replace(A_rn, A_rn + "\n      _foRecent(m); /* SMARTFIYAT_UI_V1 */", 1)

# (6) Init — skor + arama
A_call = '  document.getElementById("md-teklif").addEventListener("click", () => { kapatModal(); teklifFormModal(m, null); });'
assert s.count(A_call) == 1, "md-teklif anchor"
s = s.replace(A_call, A_call + "\n  _foSkor(m); _foFiyatInit(m); /* SMARTFIYAT_UI_V1 */", 1)

write(FP, s)
print("smartfiyat: skor karti + son-alim oneri sutunu + arama modulu eklendi")
print("marker count:", s.count("SMARTFIYAT_UI_V1"))
print("DONE.")
