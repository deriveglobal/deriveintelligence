#!/usr/bin/env python3
# NEDEN_V1 — Kokpit "neden?" drill: Marka kırılım satırı tıklanınca sebep_arastir_marj köprüsü
#   (mix/fiyat/maliyet/değişim) + anlatı + öneri INLINE açılır. Mevcut /api/bi/finans-marka-sebep
#   endpoint'i kullanılır (yeni backend YOK). Frontend-only: shells/kokpit.html. Idempotent, assert-korumalı.
import sys
FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/kokpit.html"
s = open(FP, encoding="utf-8").read()

if "NEDEN_V1" in s or "_nedenToggle" in s:
    print("zaten yamali (NEDEN_V1), atlandi"); print("DONE."); raise SystemExit

def rep(old, new, tag):
    global s
    assert s.count(old) == 1, "ankor yok/coklu: " + tag + " (n=" + str(s.count(old)) + ")"
    s = s.replace(old, new)
    print("  " + tag + ": ok")

# 1) barCard: Marka satırlarını tıklanabilir yap (data-marka + caret)
old1 = '''  const body=rows.map(r=>`<div class="row"><span class="nm" title="${esc(keyf(r))}">${esc(keyf(r))}</span>
    <span class="tr"><i style="width:${clampw((r.c||0)/mx*100)}%;background:${mcol(r.mj)}"></i></span>
    <span class="vv">${M(r.c)}M·<b class="${mcls(r.mj)}">${r.mj!=null?'%'+M(r.mj):'—'}</b></span></div>`).join("");'''
new1 = '''  const _nd=(title==="Marka"); /* NEDEN_V1 */
  const body=rows.map(r=>`<div class="row${_nd?' neden-row':''}"${_nd?` data-marka="${esc(keyf(r))}" style="cursor:pointer"`:''}><span class="nm" title="${esc(keyf(r))}">${_nd?'<span class="nd-caret" style="color:var(--mut);font-size:9px">\\u25B8</span> ':''}${esc(keyf(r))}</span>
    <span class="tr"><i style="width:${clampw((r.c||0)/mx*100)}%;background:${mcol(r.mj)}"></i></span>
    <span class="vv">${M(r.c)}M·<b class="${mcls(r.mj)}">${r.mj!=null?'%'+M(r.mj):'—'}</b></span></div>`).join("");'''
rep(old1, new1, "barCard-marka")

# 2) renderBreakdowns sonuna tıklama dinleyicisi
old2 = '''    barCard("Sezon","12 ay",sezon,r=>r.s)
  ].join("");
}'''
new2 = '''    barCard("Sezon","12 ay",sezon,r=>r.s)
  ].join("");
  $("breakdowns").querySelectorAll(".neden-row").forEach(function(tr){ tr.addEventListener("click", function(){ _nedenToggle(tr); }); }); /* NEDEN_V1 */
}'''
rep(old2, new2, "renderBreakdowns-listeners")

# 3) _nedenToggle fonksiyonu (renderBreakdowns'tan hemen once)
FN = '''/* NEDEN_V1 — marka satiri -> sebep_arastir_marj kopru (mix/fiyat/maliyet/degisim) inline */
async function _nedenToggle(row){
  var marka=row.getAttribute("data-marka");
  var cr=row.querySelector(".nd-caret");
  var nx=row.nextElementSibling;
  if(nx && nx.classList.contains("neden-sub")){ nx.remove(); if(cr)cr.textContent="\\u25B8"; return; }
  if(cr)cr.textContent="\\u25BE";
  var j; try{ j=await jget("/api/bi/finans-marka-sebep?marka="+encodeURIComponent(marka)); }catch(e){ if(cr)cr.textContent="\\u25B8"; return; }
  if(!j || j.error){ row.insertAdjacentHTML("afterend", '<div class="neden-sub"><div class="nd-an">Sebep verisi yok.</div></div>'); return; }
  var k=j.kopru||{};
  var fac=[["Maliyet",+(k.maliyet_m||0)],["Fiyat",+(k.fiyat_m||0)],["Urun mix",+(k.mix_m||0)],["Hacim deg.",+(k.degisim_m||0)]]
    .filter(function(f){return Math.abs(f[1])>0.001;}).sort(function(a,b){return Math.abs(b[1])-Math.abs(a[1]);});
  var mx=Math.max.apply(null,fac.map(function(f){return Math.abs(f[1]);}).concat([0.001]));
  var brg=fac.map(function(f){var w=Math.abs(f[1])/mx*50;var pos=f[1]>=0;
    return '<div class="nd-f"><span class="l">'+esc(f[0])+'</span><span class="nd-track"><span class="ax"></span><i class="'+(pos?'p':'n')+'" style="width:'+w+'%"></i></span><span class="v '+(pos?'p':'n')+'">'+(pos?'+':'\\u2212')+M(Math.abs(f[1]))+'M</span></div>';}).join("");
  var o=(j.marj_pct_o!=null)?M(j.marj_pct_o):'\\u2014', ss=(j.marj_pct_s!=null)?M(j.marj_pct_s):'\\u2014';
  var sah=(j.saha_ipuclari&&j.saha_ipuclari.length)?'<div class="nd-sah">\\uD83E\\uDDED sahadan: '+j.saha_ipuclari.map(esc).join(' \\u00b7 ')+'</div>':'';
  var html='<div class="neden-sub">'
    +'<div class="nd-hd"><b>Neden?</b> '+esc(marka)+' \\u00b7 marj %'+o+' \\u2192 %'+ss+' <span class="nd-guv">g\\u00fcven: '+esc(j.guven||'\\u2014')+'</span></div>'
    +'<div class="nd-brg">'+(brg||'<span class="l">k\\u00f6pr\\u00fc verisi yok</span>')+'</div>'
    +(j.anlati?'<div class="nd-an">'+esc(j.anlati)+'</div>':'')
    +(j.oneri?'<div class="nd-do">\\u2192 '+esc(j.oneri)+'</div>':'')
    +sah
    +'<div class="nd-src">kaynak: '+esc(j.kaynak||'bi_marj_atom')+'</div>'
    +'</div>';
  row.insertAdjacentHTML("afterend", html);
}

function renderBreakdowns(){'''
rep("function renderBreakdowns(){", FN, "nedenToggle-fn")

# 4) CSS (</style> oncesi)
CSS = '''  /* NEDEN_V1 */
  .neden-sub{background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.09);border-radius:10px;padding:11px 13px;margin:4px 6px 8px}
  .neden-sub .nd-hd{font-size:12px;font-weight:700;margin-bottom:9px}
  .neden-sub .nd-guv{float:right;font-weight:500;color:var(--mut);font-size:11px}
  .neden-sub .nd-f{display:flex;align-items:center;gap:9px;margin:4px 0;font-size:11.5px}
  .neden-sub .nd-f .l{width:82px;color:var(--mut)}
  .neden-sub .nd-track{position:relative;flex:1;height:9px;background:rgba(255,255,255,.05);border-radius:5px}
  .neden-sub .nd-track .ax{position:absolute;left:50%;top:0;bottom:0;width:1px;background:rgba(255,255,255,.2)}
  .neden-sub .nd-track i{position:absolute;top:1px;height:7px;border-radius:3px}
  .neden-sub .nd-track i.p{left:50%;background:#34d399}
  .neden-sub .nd-track i.n{right:50%;background:#f87171}
  .neden-sub .nd-f .v{width:66px;text-align:right;font-weight:600}
  .neden-sub .nd-f .v.p{color:#34d399}.neden-sub .nd-f .v.n{color:#f87171}
  .neden-sub .nd-an{font-size:12px;color:var(--ink2);margin:10px 0 4px;line-height:1.5}
  .neden-sub .nd-do{font-size:12px;color:var(--accent);font-weight:500}
  .neden-sub .nd-sah{font-size:11.5px;color:#93c5fd;margin-top:7px}
  .neden-sub .nd-src{font-size:10px;color:var(--mut);margin-top:9px;border-top:1px solid rgba(255,255,255,.07);padding-top:6px}
</style>'''
rep("</style>", CSS, "css")

open(FP, "w", encoding="utf-8").write(s)
print("yamalandi: NEDEN_V1 (marka neden? drill, frontend-only)")
print("DONE.")
