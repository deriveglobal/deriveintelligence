#!/usr/bin/env python3
# OMURGA 24 — Marka tıkla-aç drill: /api/bi/finans-marka-detay + Marka Trendi satırı tıklanınca
# ciro/adet/marj aylık sparkline (kapsam + güncel-maliyet + kısmi-ay notu). server + bi.js.
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
BIJS='/opt/krb-assessment/shells/bi.js'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)

# ───────── 1. SERVER endpoint ─────────
ENDPOINT = r'''    if (request.method === 'GET' && url.pathname === '/api/bi/finans-marka-detay') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        const marka = (url.searchParams.get('marka') || '').trim();
        if (!marka) { sendJson(response, 400, { error: 'marka gerekli' }); return; }
        const r = await query(`
          WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) AS bmaliyet
                        FROM bi_stok_hareket WHERE tenant_id=$1::uuid AND giris>0 GROUP BY kalem_kodu)
          SELECT to_char(date_trunc('month',s.fatura_tarihi),'YYYY-MM') AS donem,
                 round(sum(s.satir_tutar)) AS ciro,
                 sum(s.miktar)::bigint AS adet,
                 round(sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END)) AS marj,
                 round(100.0*count(*) FILTER (WHERE km.bmaliyet IS NOT NULL)/nullif(count(*),0)) AS marj_kapsam
            FROM bi_satis_faturalari s LEFT JOIN km ON km.kalem_kodu=s.kalem_kodu
           WHERE s.tenant_id=$1::text AND s.ebat IS NOT NULL AND upper(s.marka)=upper($2)
             AND s.fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - interval '17 month')
           GROUP BY 1 ORDER BY 1`, [T, marka]);
        const noktalar = r.rows.map(x => ({ donem:x.donem, ciro:Number(x.ciro),
          adet:Number(x.adet), marj:x.marj==null?null:Number(x.marj),
          marj_kapsam:x.marj_kapsam==null?null:Number(x.marj_kapsam) }));
        sendJson(response, 200, { marka, noktalar });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }

'''
SRV_ANCHOR = "    if (request.method === 'GET' && url.pathname === '/api/bi/yukle/durum') {"
s=rd(SRV)
if '/api/bi/finans-marka-detay' in s:
    print('  ⏭ server zaten yamalı')
else:
    if s.count(SRV_ANCHOR)!=1:
        print(f'  ✗ SERVER anchor {s.count(SRV_ANCHOR)} kez — DURDU'); sys.exit(1)
    s=s.replace(SRV_ANCHOR, ENDPOINT+SRV_ANCHOR, 1)
    wr(SRV,s); print('  ✅ server: /api/bi/finans-marka-detay eklendi')

# ───────── 2. BIJS ─────────
b=rd(BIJS)

# 2a. satır → tıklanabilir + caret + detay container
ROW_OLD = r'''        h += '<div class="satir"><div>'+esc(String(x.ad||'').slice(0,24))+'</div>'
           + '<div class="n">'+_M(x.h1_2025)+' → '+_M(x.h1_2026)
           + ' <span style="color:'+renk+';font-size:12px;margin-left:6px">'+ok+' '+(yoy==null?'—':yoy+'%')+'</span></div></div>';'''
ROW_NEW = r'''        var _mk=esc(String(x.ad||''));
        h += '<div class="marka-satir satir" data-marka="'+_mk+'" style="cursor:pointer">'
           + '<div><span class="mk-ok" style="display:inline-block;width:12px;color:var(--tx-3);transition:transform .15s">▸</span> '+esc(String(x.ad||'').slice(0,24))+'</div>'
           + '<div class="n">'+_M(x.h1_2025)+' → '+_M(x.h1_2026)
           + ' <span style="color:'+renk+';font-size:12px;margin-left:6px">'+ok+' '+(yoy==null?'—':yoy+'%')+'</span></div></div>';
        h += '<div class="marka-detay" style="display:none;padding:0 0 8px 20px"></div>';'''

# 2b. commit sonrası tıklama bağla
WIRE_OLD = r'''      h += '</div><div style="font-size:11px;color:var(--tx-3);margin-top:6px">Kaynak: bi_metrik_gecmis · ciro_lastik × marka · güven: kesin</div>';
      el.innerHTML = h;'''
WIRE_NEW = r'''      h += '</div><div style="font-size:11px;color:var(--tx-3);margin-top:6px">Kaynak: bi_metrik_gecmis · ciro_lastik × marka · güven: kesin · <span style="color:var(--tx-2)">markaya tıkla → ciro/adet/marj</span></div>';
      el.innerHTML = h;
      el.querySelectorAll('.marka-satir').forEach(function(row){ row.addEventListener('click', function(){ _markaDetay(row); }); });'''

# 2c. _markaDetay fonksiyonu (─ _finansTrendCiz'den önce)
FUNC_ANCHOR = '  async function _finansTrendCiz(){'
FUNC_NEW = r'''  async function _markaDetay(row){
    var det = row.nextElementSibling;
    if(!det || !det.classList.contains('marka-detay')) return;
    var caret = row.querySelector('.mk-ok');
    if(det.style.display!=='none'){ det.style.display='none'; if(caret)caret.style.transform=''; return; }
    det.style.display='block'; if(caret)caret.style.transform='rotate(90deg)';
    if(det.getAttribute('data-yuklendi')==='1') return;
    det.innerHTML='<div style="font-size:12px;color:var(--tx-2);padding:8px 0">yükleniyor…</div>';
    var mk=row.getAttribute('data-marka'); var d={noktalar:[]};
    try{ var r=await fetch('/api/bi/finans-marka-detay?marka='+encodeURIComponent(mk),{credentials:'same-origin'}); d=await r.json(); if(d.error)throw new Error(d.error);}
    catch(e){ det.innerHTML='<div class="d-kirmizi" style="font-size:12px;padding:6px 0">detay gelmedi: '+esc(e.message)+'</div>'; return; }
    var pts=d.noktalar||[];
    if(pts.length<2){ det.innerHTML='<div style="font-size:12px;color:var(--tx-2);padding:6px 0">yeterli geçmiş yok</div>'; det.setAttribute('data-yuklendi','1'); return; }
    var _n=new Date(); var curAy=_n.getFullYear()+'-'+String(_n.getMonth()+1).padStart(2,'0');
    var kismi=(pts[pts.length-1].donem===curAy);
    var kaps=pts[pts.length-1].marj_kapsam;
    var metr=[
      {ad:'Ciro', renk:'#5AA9E6', get:function(p){return p.ciro;}, fmt:function(v){return _M(v);}},
      {ad:'Adet', renk:'#B98AE6', get:function(p){return p.adet;}, fmt:function(v){return Number(v).toLocaleString('tr-TR');}},
      {ad:'Marj', renk:'#7EC97E', get:function(p){return p.marj;}, fmt:function(v){return v==null?'—':_M(v);}}
    ];
    var hh='';
    metr.forEach(function(m,i){
      var vals=pts.map(m.get);
      var clean=vals.map(function(v){return v==null?0:v;});
      var cur=vals[vals.length-1];
      hh+='<div style="display:flex;align-items:center;gap:12px;padding:7px 0'+(i>0?';border-top:0.5px solid var(--cizgi)':'')+'">'
        + '<div style="width:52px;font-size:12px;color:var(--tx-2)">'+m.ad+'</div>'
        + '<div style="width:110px">'+_spark(clean,110,26,m.renk,kismi)+'</div>'
        + '<div class="n" style="flex:1;text-align:right;font-size:13px">'+m.fmt(cur)+(kismi?'<span style="font-size:10px;color:var(--tx-2)"> ○</span>':'')+'</div></div>';
    });
    hh+='<div style="font-size:10px;color:var(--tx-3);margin-top:5px;line-height:1.6">'+pts.length+' ay · marj kapsam %'+(kaps==null?'—':kaps)+(kaps!=null&&kaps<100?' (eksik maliyet)':'')+' · marj güncel maliyet bazı · ○ kapanmamış ay</div>';
    det.innerHTML=hh; det.setAttribute('data-yuklendi','1');
  }

  async function _finansTrendCiz(){'''

if 'marka-satir' in b and '_markaDetay' in b:
    print('  ⏭ bi.js zaten yamalı')
else:
    for name, old in [('ROW',ROW_OLD),('WIRE',WIRE_OLD),('FUNC_ANCHOR',FUNC_ANCHOR)]:
        c=b.count(old)
        if c!=1:
            print(f'  ✗ BIJS {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
    b=b.replace(ROW_OLD,ROW_NEW,1).replace(WIRE_OLD,WIRE_NEW,1).replace(FUNC_ANCHOR,FUNC_NEW,1)
    wr(BIJS,b); print('  ✅ bi.js: satır tıklanabilir + wiring + _markaDetay')

# ───────── 3. node --check + doğrula ─────────
for p in [SRV,BIJS]:
    r=subprocess.run(['node','--check',p],capture_output=True,text=True)
    print(('  ✅ node --check OK: ' if r.returncode==0 else '  ✗ SYNTAX: ')+p)
    if r.returncode!=0: print(r.stderr); sys.exit(1)
s2,b2=rd(SRV),rd(BIJS)
print('  endpoint :', '/api/bi/finans-marka-detay' in s2)
print('  satır    :', 'class="marka-satir satir"' in b2)
print('  wiring   :', "querySelectorAll('.marka-satir')" in b2)
print('  func     :', 'async function _markaDetay' in b2)
print('\n  ✅ YAMA TAMAM — sırada docker build')
