#!/usr/bin/env python3
# OMURGA 21 — DSO/Stok/Alacak trendi ekrana: /api/bi/finans-seri + sparkline UI.
# Full-text replacement + idempotent + node --check + varlık doğrula.
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
BIJS='/opt/krb-assessment/shells/bi.js'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)

# ───────── 1. SERVER: /api/bi/finans-seri (dso+stok+alacak, son 18 ay) ─────────
ENDPOINT = r'''    if (request.method === 'GET' && url.pathname === '/api/bi/finans-seri') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        const r = await query(`
          SELECT metrik, to_char(donem,'YYYY-MM') AS donem, deger, guven
            FROM bi_metrik_gecmis
           WHERE tenant_id=$1::uuid AND boyut_tipi='sirket'
             AND metrik IN ('dso','stok_deger','alacak')
             AND donem >= (CURRENT_DATE - INTERVAL '18 months')
           ORDER BY metrik, donem`, [T]);
        const seriler = {};
        for (const row of r.rows) {
          (seriler[row.metrik] = seriler[row.metrik] || []).push({ donem: row.donem, deger: Number(row.deger), guven: row.guven });
        }
        sendJson(response, 200, { seriler });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }

'''
SRV_ANCHOR = "    if (request.method === 'GET' && url.pathname === '/api/bi/yukle/durum') {"
s = rd(SRV)
if '/api/bi/finans-seri' in s:
    print('  ⏭ server zaten yamalı')
else:
    if s.count(SRV_ANCHOR) != 1:
        print(f'  ✗ SERVER anchor {s.count(SRV_ANCHOR)} kez — DURDU'); sys.exit(1)
    s = s.replace(SRV_ANCHOR, ENDPOINT + SRV_ANCHOR, 1)
    wr(SRV, s); print('  ✅ server: /api/bi/finans-seri eklendi')

# ───────── 2. BIJS: sparkline + _finansSeriCiz fonksiyonları ─────────
b = rd(BIJS)
FUNCS = r'''  function _spark(vals, w, hh, col){
    if(!vals || vals.length<2) return '';
    var mn=Math.min.apply(null,vals), mx=Math.max.apply(null,vals), rng=(mx-mn)||1;
    var pts=vals.map(function(v,i){
      var x=(i/(vals.length-1))*w;
      var y=hh-((v-mn)/rng)*(hh-4)-2;
      return x.toFixed(1)+','+y.toFixed(1);
    }).join(' ');
    var lx=w, ly=hh-((vals[vals.length-1]-mn)/rng)*(hh-4)-2;
    return '<svg width="'+w+'" height="'+hh+'" viewBox="0 0 '+w+' '+hh+'" style="display:block">'
         + '<polyline points="'+pts+'" fill="none" stroke="'+col+'" stroke-width="1.5" stroke-linejoin="round"/>'
         + '<circle cx="'+lx.toFixed(1)+'" cy="'+ly.toFixed(1)+'" r="2.5" fill="'+col+'"/></svg>';
  }

  async function _finansSeriCiz(){
    var el=document.getElementById('finans-seri-bolum'); if(!el) return;
    var d={seriler:{}};
    try{ var r=await fetch('/api/bi/finans-seri',{credentials:'same-origin'}); d=await r.json(); }
    catch(e){ el.innerHTML=''; return; }
    var S=d.seriler||{};
    var conf=[
      {key:'dso', ad:'DSO — tahsilat süresi', renk:'#E8B84B', fmt:function(v){return Math.round(v)+' gün';}, tersIyi:true},
      {key:'stok_deger', ad:'Stok değeri', renk:'#5AA9E6', fmt:function(v){return _M(v);}, tersIyi:false},
      {key:'alacak', ad:'Alacak', renk:'#7EC97E', fmt:function(v){return _M(v);}, tersIyi:false}
    ];
    var govde='';
    conf.forEach(function(c,idx){
      var seri=S[c.key]; if(!seri||seri.length<2) return;
      var vals=seri.map(function(x){return x.deger;});
      var cur=vals[vals.length-1];
      var y12= seri.length>12 ? vals[vals.length-13] : vals[0];
      var dpct= y12 ? Math.round(100*(cur-y12)/Math.abs(y12)) : null;
      var okYon= c.tersIyi ? (dpct<0) : (dpct>0);
      var okRenk= dpct==null?'var(--tx-2)':(okYon?'var(--yesil)':'var(--kirmizi)');
      var ok= dpct==null?'':(dpct>0?'▲':'▼');
      govde+='<div style="display:flex;align-items:center;gap:14px;padding:12px 0'+(idx>0?';border-top:0.5px solid var(--cizgi)':'')+'">'
        + '<div style="flex:1;min-width:0"><div style="font-size:13px;margin-bottom:2px">'+esc(c.ad)+'</div>'
        + '<div style="font-size:11px;color:var(--tx-2)">'+seri.length+' ay · '+esc(seri[0].donem)+' → bugün</div></div>'
        + '<div style="width:120px">'+_spark(vals,120,32,c.renk)+'</div>'
        + '<div style="text-align:right;min-width:96px">'
        + '<div class="n" style="font-size:15px">'+c.fmt(cur)+'</div>'
        + '<div style="font-size:11px;color:'+okRenk+'">'+ok+' '+(dpct==null?'—':(Math.abs(dpct)+'% · 12 ay'))+'</div>'
        + '</div></div>';
    });
    if(!govde){ el.innerHTML=''; return; }
    var h='<div class="etiket" style="margin-bottom:10px">METRİK TRENDİ · son 18 ay</div>';
    h+='<div class="kart">'+govde
      + '<div style="font-size:11px;color:var(--tx-2);margin-top:8px;line-height:1.6">'
      + 'Son nokta ölçüldü (kesin); geçmiş aylar rekonstrüksiyon (yaklaşık ~%7). Kaynak: metrik omurgası.</div></div>';
    el.innerHTML=h;
  }

  async function _finansTrendCiz(){'''
FUNCS_ANCHOR = '    async function _finansTrendCiz(){'
CONT_ANCHOR = "    h += '<div id=\"finans-trend-bolum\" style=\"margin-top:28px\"><div style=\"color:var(--tx-2);font-size:13px\">Marka trendi yükleniyor…</div></div>';"
CONT_NEW = CONT_ANCHOR + "\n    h += '<div id=\"finans-seri-bolum\" style=\"margin-top:28px\"></div>';"
CALL_ANCHOR = '      _finansTrendCiz();'
CALL_NEW = '      _finansTrendCiz();\n      _finansSeriCiz();'

if 'finans-seri-bolum' in b and '_finansSeriCiz' in b:
    print('  ⏭ bi.js zaten yamalı')
else:
    for name, old in [('FUNCS_ANCHOR',FUNCS_ANCHOR),('CONT',CONT_ANCHOR),('CALL',CALL_ANCHOR)]:
        c=b.count(old)
        if c!=1:
            print(f'  ✗ BIJS {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
    b=b.replace(FUNCS_ANCHOR, FUNCS, 1)
    b=b.replace(CONT_ANCHOR, CONT_NEW, 1)
    b=b.replace(CALL_ANCHOR, CALL_NEW, 1)
    wr(BIJS,b); print('  ✅ bi.js: sparkline + _finansSeriCiz + container + call')

# ───────── 3. node --check ─────────
for p in [SRV,BIJS]:
    r=subprocess.run(['node','--check',p],capture_output=True,text=True)
    print(('  ✅ node --check OK: ' if r.returncode==0 else '  ✗ SYNTAX: ')+p)
    if r.returncode!=0: print(r.stderr); sys.exit(1)

# ───────── 4. varlık doğrula ─────────
s2,b2=rd(SRV),rd(BIJS)
print('  endpoint  :', '/api/bi/finans-seri' in s2)
print('  container :', 'id="finans-seri-bolum"' in b2)
print('  call      :', '_finansSeriCiz();' in b2)
print('  func      :', 'async function _finansSeriCiz' in b2)
print('  spark     :', 'function _spark(' in b2)
print('\n  ✅ YAMA TAMAM — sırada: docker build + compose up --force-recreate')
