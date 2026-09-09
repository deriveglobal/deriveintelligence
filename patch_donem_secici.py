#!/usr/bin/env python3
# OMURGA 26 — Marka Trendi dönem seçici (Son 1/3/6/12 ay). 2 endpoint (ay param, kapanmış-ay YoY)
# + 2 UI fonksiyon (seçici + paylaşılan _markaAy + drill pencereyi yansıtır).
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
BIJS='/opt/krb-assessment/shells/bi.js'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)

# ═══════════ SERVER 1: finans-trend ═══════════
TREND_OLD = """      if (request.method === 'GET' && url.pathname === '/api/bi/finans-trend') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        const metrik = url.searchParams.get('metrik') || 'ciro_lastik';
        const boyut  = url.searchParams.get('boyut')  || 'marka';
        const r = await query(`
          SELECT boyut_deger AS ad,
                 round(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01')) AS h1_2025,
                 round(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')) AS h1_2026,
                 round(100.0*(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')
                       - sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'))
                       / nullif(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'),0)) AS yoy_pct
            FROM bi_metrik_gecmis
           WHERE tenant_id=$1::uuid AND metrik=$2 AND boyut_tipi=$3
           GROUP BY boyut_deger
          HAVING sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01') > 0
           ORDER BY h1_2026 DESC NULLS LAST LIMIT 12`, [T, metrik, boyut]);
        sendJson(response, 200, { metrik, boyut, satirlar: r.rows });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }"""
TREND_NEW = """      if (request.method === 'GET' && url.pathname === '/api/bi/finans-trend') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        const metrik = url.searchParams.get('metrik') || 'ciro_lastik';
        const boyut  = url.searchParams.get('boyut')  || 'marka';
        const ay = [1,3,6,12].includes(parseInt(url.searchParams.get('ay'))) ? parseInt(url.searchParams.get('ay')) : 6;
        const r = await query(`
          SELECT boyut_deger AS ad,
                 round(sum(deger) FILTER (WHERE donem >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$4::int+12)) AND donem < (date_trunc('month',CURRENT_DATE) - make_interval(months=>12)))) AS onceki,
                 round(sum(deger) FILTER (WHERE donem >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$4::int)) AND donem < date_trunc('month',CURRENT_DATE))) AS simdi,
                 round(100.0*(sum(deger) FILTER (WHERE donem >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$4::int)) AND donem < date_trunc('month',CURRENT_DATE))
                       - sum(deger) FILTER (WHERE donem >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$4::int+12)) AND donem < (date_trunc('month',CURRENT_DATE) - make_interval(months=>12))))
                       / nullif(sum(deger) FILTER (WHERE donem >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$4::int+12)) AND donem < (date_trunc('month',CURRENT_DATE) - make_interval(months=>12))),0)) AS yoy_pct
            FROM bi_metrik_gecmis
           WHERE tenant_id=$1::uuid AND metrik=$2 AND boyut_tipi=$3
           GROUP BY boyut_deger
          HAVING sum(deger) FILTER (WHERE donem >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$4::int)) AND donem < date_trunc('month',CURRENT_DATE)) > 0
           ORDER BY simdi DESC NULLS LAST LIMIT 12`, [T, metrik, boyut, ay]);
        sendJson(response, 200, { metrik, boyut, ay, satirlar: r.rows });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }"""

# ═══════════ SERVER 2: finans-marka-detay ═══════════
DETAY_OLD = """    if (request.method === 'GET' && url.pathname === '/api/bi/finans-marka-detay') {
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
    }"""
DETAY_NEW = """    if (request.method === 'GET' && url.pathname === '/api/bi/finans-marka-detay') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        const marka = (url.searchParams.get('marka') || '').trim();
        const ay = [1,3,6,12].includes(parseInt(url.searchParams.get('ay'))) ? parseInt(url.searchParams.get('ay')) : 6;
        if (!marka) { sendJson(response, 400, { error: 'marka gerekli' }); return; }
        const KM = `WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) AS bmaliyet FROM bi_stok_hareket WHERE tenant_id=$1::uuid AND giris>0 GROUP BY kalem_kodu)`;
        const [cur, prev] = await Promise.all([
          query(`${KM}
            SELECT to_char(date_trunc('month',s.fatura_tarihi),'YYYY-MM') AS donem,
                   round(sum(s.satir_tutar)) AS ciro, sum(s.miktar)::bigint AS adet,
                   round(sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END)) AS marj,
                   round(100.0*count(*) FILTER (WHERE km.bmaliyet IS NOT NULL)/nullif(count(*),0)) AS marj_kapsam
              FROM bi_satis_faturalari s LEFT JOIN km ON km.kalem_kodu=s.kalem_kodu
             WHERE s.tenant_id=$1::text AND s.ebat IS NOT NULL AND s.miktar > 0 AND upper(s.marka)=upper($2)
               AND s.fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$3::int))
               AND s.fatura_tarihi < date_trunc('month',CURRENT_DATE)
             GROUP BY 1 ORDER BY 1`, [T, marka, ay]),
          query(`${KM}
            SELECT round(sum(s.satir_tutar)) AS ciro, sum(s.miktar)::bigint AS adet,
                   round(sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END)) AS marj
              FROM bi_satis_faturalari s LEFT JOIN km ON km.kalem_kodu=s.kalem_kodu
             WHERE s.tenant_id=$1::text AND s.ebat IS NOT NULL AND s.miktar > 0 AND upper(s.marka)=upper($2)
               AND s.fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$3::int+12))
               AND s.fatura_tarihi < (date_trunc('month',CURRENT_DATE) - make_interval(months=>12))`, [T, marka, ay])
        ]);
        const noktalar = cur.rows.map(x => ({ donem:x.donem, ciro:Number(x.ciro),
          adet:Number(x.adet), marj:x.marj==null?null:Number(x.marj),
          marj_kapsam:x.marj_kapsam==null?null:Number(x.marj_kapsam) }));
        const p = prev.rows[0] || {};
        const onceki = { ciro:p.ciro==null?null:Number(p.ciro), adet:p.adet==null?null:Number(p.adet), marj:p.marj==null?null:Number(p.marj) };
        sendJson(response, 200, { marka, ay, noktalar, onceki });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }"""

# ═══════════ BIJS 1: _markaDetay (var _markaAy önek + pencere-farkında) ═══════════
MD_OLD = """  async function _markaDetay(row){
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
      {ad:'Ciro', key:'ciro', renk:'#5AA9E6', get:function(p){return p.ciro;}, fmt:function(v){return _M(v);}},
      {ad:'Adet', key:'adet', renk:'#B98AE6', get:function(p){return p.adet;}, fmt:function(v){return Number(v).toLocaleString('tr-TR');}},
      {ad:'Marj', key:'marj', renk:'#7EC97E', get:function(p){return p.marj;}, fmt:function(v){return v==null?'—':_M(v);}}
    ];
    var hh='';
    metr.forEach(function(m,i){
      var vals=pts.map(m.get);
      var clean=vals.map(function(v){return v==null?0:v;});
      var cur=vals[vals.length-1];
      hh+='<div style="display:flex;align-items:center;gap:12px;padding:7px 0'+(i>0?';border-top:0.5px solid var(--cizgi)':'')+'">'
        + '<div style="width:52px;font-size:12px;color:var(--tx-2)">'+m.ad+_metrikInfo(m.key)+'</div>'
        + '<div style="width:110px">'+_spark(clean,110,26,m.renk,kismi)+'</div>'
        + '<div class="n" style="flex:1;text-align:right;font-size:13px">'+m.fmt(cur)+(kismi?'<span style="font-size:10px;color:var(--tx-2)"> ○</span>':'')+'</div></div>';
    });
    hh+='<div style="font-size:10px;color:var(--tx-3);margin-top:5px;line-height:1.6">'+pts.length+' ay · marj kapsam %'+(kaps==null?'—':kaps)+(kaps!=null&&kaps<100?' (eksik maliyet)':'')+' · marj güncel maliyet bazı · ○ kapanmamış ay</div>';
    det.innerHTML=hh; det.setAttribute('data-yuklendi','1');
  }"""
MD_NEW = """  var _markaAy = 6;

  async function _markaDetay(row){
    var det = row.nextElementSibling;
    if(!det || !det.classList.contains('marka-detay')) return;
    var caret = row.querySelector('.mk-ok');
    if(det.style.display!=='none'){ det.style.display='none'; if(caret)caret.style.transform=''; return; }
    det.style.display='block'; if(caret)caret.style.transform='rotate(90deg)';
    if(det.getAttribute('data-yuklendi')===String(_markaAy)) return;
    det.innerHTML='<div style="font-size:12px;color:var(--tx-2);padding:8px 0">yükleniyor…</div>';
    var mk=row.getAttribute('data-marka'); var d={noktalar:[],onceki:{}};
    try{ var r=await fetch('/api/bi/finans-marka-detay?marka='+encodeURIComponent(mk)+'&ay='+_markaAy,{credentials:'same-origin'}); d=await r.json(); if(d.error)throw new Error(d.error);}
    catch(e){ det.innerHTML='<div class="d-kirmizi" style="font-size:12px;padding:6px 0">detay gelmedi: '+esc(e.message)+'</div>'; return; }
    var pts=d.noktalar||[]; var onc=d.onceki||{};
    if(!pts.length){ det.innerHTML='<div style="font-size:12px;color:var(--tx-2);padding:6px 0">bu pencerede satış yok</div>'; det.setAttribute('data-yuklendi',String(_markaAy)); return; }
    var kaps=pts[pts.length-1].marj_kapsam;
    var metr=[
      {ad:'Ciro', key:'ciro', fld:'ciro', renk:'#5AA9E6', fmt:function(v){return v==null?'—':_M(v);}},
      {ad:'Adet', key:'adet', fld:'adet', renk:'#B98AE6', fmt:function(v){return v==null?'—':Number(v).toLocaleString('tr-TR');}},
      {ad:'Marj', key:'marj', fld:'marj', renk:'#7EC97E', fmt:function(v){return v==null?'—':_M(v);}}
    ];
    var hh='';
    metr.forEach(function(m,i){
      var vals=pts.map(function(p){return p[m.fld]==null?0:p[m.fld];});
      var toplam=pts.reduce(function(a,p){return a+(p[m.fld]==null?0:p[m.fld]);},0);
      var varMi=(m.fld!=='marj') || pts.some(function(p){return p.marj!=null;});
      var cur=varMi?toplam:null;
      var prev=onc[m.fld];
      var dpct=(prev!=null&&prev!=0&&cur!=null)?Math.round(100*(cur-prev)/Math.abs(prev)):null;
      var okc=dpct==null?'var(--tx-2)':(dpct>=0?'var(--yesil)':'var(--kirmizi)');
      var oki=dpct==null?'':(dpct>=0?'▲':'▼');
      var spk=pts.length>=2 ? _spark(vals,110,26,m.renk,false) : '<div style="font-size:10px;color:var(--tx-3);text-align:center;padding-top:8px">tek ay</div>';
      hh+='<div style="display:flex;align-items:center;gap:12px;padding:7px 0'+(i>0?';border-top:0.5px solid var(--cizgi)':'')+'">'
        + '<div style="width:52px;font-size:12px;color:var(--tx-2)">'+m.ad+_metrikInfo(m.key)+'</div>'
        + '<div style="width:110px">'+spk+'</div>'
        + '<div class="n" style="flex:1;text-align:right;font-size:13px">'+m.fmt(cur)+' <span style="font-size:11px;color:'+okc+'">'+oki+' '+(dpct==null?'—':Math.abs(dpct)+'%')+'</span></div></div>';
    });
    hh+='<div style="font-size:10px;color:var(--tx-3);margin-top:5px;line-height:1.6">'+pts.length+' ay penceresi · YoY geçen yıl aynı dönem · marj kapsam %'+(kaps==null?'—':kaps)+(kaps!=null&&kaps<100?' (eksik maliyet)':'')+' · marj brüt, güncel maliyet bazı</div>';
    det.innerHTML=hh; det.setAttribute('data-yuklendi',String(_markaAy));
  }"""

# ═══════════ BIJS 2: _finansTrendCiz (seçici + dinamik başlık + onceki/simdi) ═══════════
FT_OLD = """  async function _finansTrendCiz(){
    var el = document.getElementById('finans-trend-bolum'); if(!el) return;
    try{
      var r = await fetch('/api/bi/finans-trend?metrik=ciro_lastik&boyut=marka', {credentials:'same-origin'});
      var d = await r.json(); if(d.error) throw new Error(d.error);
      var rows = d.satirlar || [];
      if(!rows.length){ el.innerHTML=''; return; }
      var h = '<div class="etiket" style="margin-bottom:10px">MARKA TRENDİ — lastik cirosu · H1 2025 → H1 2026'+_metrikInfo('ciro')+'</div><div class="kart">';
      rows.forEach(function(x){
        var yoy = x.yoy_pct;
        var renk = (yoy==null) ? 'var(--tx-2)' : (Number(yoy)>=0 ? '#34d399' : '#f87171');
        var ok = (yoy==null) ? '' : (Number(yoy)>=0 ? '▲' : '▼');
        var _mk=esc(String(x.ad||''));
        h += '<div class="marka-satir satir" data-marka="'+_mk+'" style="cursor:pointer">'
           + '<div><span class="mk-ok" style="display:inline-block;width:12px;color:var(--tx-3);transition:transform .15s">▸</span> '+esc(String(x.ad||'').slice(0,24))+'</div>'
           + '<div class="n">'+_M(x.h1_2025)+' → '+_M(x.h1_2026)
           + ' <span style="color:'+renk+';font-size:12px;margin-left:6px">'+ok+' '+(yoy==null?'—':yoy+'%')+'</span></div></div>';
        h += '<div class="marka-detay" style="display:none;padding:0 0 8px 20px"></div>';
      });
      h += '</div><div style="font-size:11px;color:var(--tx-3);margin-top:6px">Kaynak: bi_metrik_gecmis · ciro_lastik × marka · güven: kesin · <span style="color:var(--tx-2)">markaya tıkla → ciro/adet/marj</span></div>';
      el.innerHTML = h;
      el.querySelectorAll('.marka-satir').forEach(function(row){ row.addEventListener('click', function(){ _markaDetay(row); }); });
    }catch(e){ el.innerHTML = '<div class="d-kirmizi" style="font-size:12px">Marka trendi gelmedi: '+esc(e.message)+'</div>'; }
  }"""
FT_NEW = """  async function _finansTrendCiz(){
    var el = document.getElementById('finans-trend-bolum'); if(!el) return;
    try{
      var r = await fetch('/api/bi/finans-trend?metrik=ciro_lastik&boyut=marka&ay='+_markaAy, {credentials:'same-origin'});
      var d = await r.json(); if(d.error) throw new Error(d.error);
      var rows = d.satirlar || [];
      var _aylarTR=['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
      var _n=new Date(); var _end=new Date(_n.getFullYear(), _n.getMonth(), 1);
      var _cs=new Date(_end); _cs.setMonth(_cs.getMonth()-_markaAy);
      var _last=new Date(_end); _last.setMonth(_last.getMonth()-1);
      function _lbl(dd){ return _aylarTR[dd.getMonth()]+' '+dd.getFullYear(); }
      var _aralik = (_markaAy===1) ? _lbl(_last) : (_lbl(_cs)+'–'+_lbl(_last));
      var _sec='<div style="display:flex;gap:6px;margin-bottom:10px">';
      [1,3,6,12].forEach(function(nn){
        var aktif=(nn===_markaAy);
        _sec+='<button class="donem-btn" data-ay="'+nn+'" style="font-size:11px;padding:4px 10px;border-radius:7px;cursor:pointer;border:0.5px solid '+(aktif?'var(--tx-2)':'var(--cizgi-g)')+';background:transparent;color:'+(aktif?'var(--tx-1)':'var(--tx-2)')+';font-weight:'+(aktif?'600':'400')+'">'+nn+' ay</button>';
      });
      _sec+='</div>';
      var h = '<div class="etiket" style="margin-bottom:6px">MARKA TRENDİ — lastik cirosu · '+_aralik+' <span style="color:var(--tx-3);font-weight:400">(YoY)</span>'+_metrikInfo('ciro')+'</div>'+_sec;
      if(!rows.length){ el.innerHTML=h+'<div style="font-size:12px;color:var(--tx-2)">bu pencerede veri yok</div>';
        el.querySelectorAll('.donem-btn').forEach(function(bt){ bt.addEventListener('click',function(){ _markaAy=parseInt(bt.getAttribute('data-ay')); _finansTrendCiz(); }); }); return; }
      h += '<div class="kart">';
      rows.forEach(function(x){
        var yoy = x.yoy_pct;
        var renk = (yoy==null) ? 'var(--tx-2)' : (Number(yoy)>=0 ? '#34d399' : '#f87171');
        var ok = (yoy==null) ? '' : (Number(yoy)>=0 ? '▲' : '▼');
        var _mk=esc(String(x.ad||''));
        h += '<div class="marka-satir satir" data-marka="'+_mk+'" style="cursor:pointer">'
           + '<div><span class="mk-ok" style="display:inline-block;width:12px;color:var(--tx-3);transition:transform .15s">▸</span> '+esc(String(x.ad||'').slice(0,24))+'</div>'
           + '<div class="n">'+_M(x.onceki)+' → '+_M(x.simdi)
           + ' <span style="color:'+renk+';font-size:12px;margin-left:6px">'+ok+' '+(yoy==null?'—':yoy+'%')+'</span></div></div>';
        h += '<div class="marka-detay" style="display:none;padding:0 0 8px 20px"></div>';
      });
      h += '</div><div style="font-size:11px;color:var(--tx-3);margin-top:6px">Kaynak: bi_metrik_gecmis · ciro_lastik × marka · güven: kesin · '+_aralik+' vs geçen yıl aynı dönem · <span style="color:var(--tx-2)">markaya tıkla → ciro/adet/marj</span></div>';
      el.innerHTML = h;
      el.querySelectorAll('.donem-btn').forEach(function(bt){ bt.addEventListener('click',function(){ _markaAy=parseInt(bt.getAttribute('data-ay')); _finansTrendCiz(); }); });
      el.querySelectorAll('.marka-satir').forEach(function(row){ row.addEventListener('click', function(){ _markaDetay(row); }); });
    }catch(e){ el.innerHTML = '<div class="d-kirmizi" style="font-size:12px">Marka trendi gelmedi: '+esc(e.message)+'</div>'; }
  }"""

s=rd(SRV); b=rd(BIJS)
if 'ORDER BY simdi DESC' in s and 'var _markaAy' in b:
    print('  ⏭ zaten yamalı'); sys.exit(0)

for name, old, src in [('TREND',TREND_OLD,'s'),('DETAY',DETAY_OLD,'s'),('MD',MD_OLD,'b'),('FT',FT_OLD,'b')]:
    hay = s if src=='s' else b
    c=hay.count(old)
    if c!=1:
        print(f'  ✗ {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)

s=s.replace(TREND_OLD,TREND_NEW,1).replace(DETAY_OLD,DETAY_NEW,1)
b=b.replace(MD_OLD,MD_NEW,1).replace(FT_OLD,FT_NEW,1)
wr(SRV,s); wr(BIJS,b)
print('  ✅ server: finans-trend + finans-marka-detay (ay param)')
print('  ✅ bi.js: _markaAy + seçici + drill pencere-farkında')

for p in [SRV,BIJS]:
    r=subprocess.run(['node','--check',p],capture_output=True,text=True)
    print(('  ✅ node --check OK: ' if r.returncode==0 else '  ✗ SYNTAX: ')+p)
    if r.returncode!=0: print(r.stderr); sys.exit(1)
s2,b2=rd(SRV),rd(BIJS)
print('  trend ay :', 'ORDER BY simdi DESC' in s2)
print('  detay ay :', 'ay, noktalar, onceki' in s2)
print('  _markaAy :', 'var _markaAy = 6;' in b2)
print('  seçici   :', 'donem-btn' in b2)
print('  onceki/simdi:', '_M(x.onceki)' in b2)
print('\n  ✅ YAMA TAMAM — sırada docker build')
