#!/usr/bin/env python3
# OMURGA 23 — METRİK TRENDİ: son nokta cari-ay ise "kapanmamış ay" rozeti (kesik segment + boş halka + ○ + dipnot).
# UI-only (bi.js). 4 hedefli değişim + node --check + doğrula.
import sys, subprocess
BIJS='/opt/krb-assessment/shells/bi.js'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
b=rd(BIJS)

if 'curAy' in b and 'partial' in b:
    print('  ⏭ zaten yamalı'); sys.exit(0)

# 1) _spark: partial parametresi (kesik son segment + boş halka)
SPARK_OLD = r'''  function _spark(vals, w, hh, col){
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
  }'''
SPARK_NEW = r'''  function _spark(vals, w, hh, col, partial){
    if(!vals || vals.length<2) return '';
    var mn=Math.min.apply(null,vals), mx=Math.max.apply(null,vals), rng=(mx-mn)||1;
    var xy=vals.map(function(v,i){ return { x:(i/(vals.length-1))*w, y:hh-((v-mn)/rng)*(hh-4)-2 }; });
    function pstr(a){ return a.map(function(p){return p.x.toFixed(1)+','+p.y.toFixed(1);}).join(' '); }
    var b=xy[xy.length-1];
    var svg='<svg width="'+w+'" height="'+hh+'" viewBox="0 0 '+w+' '+hh+'" style="display:block">';
    if(partial && xy.length>=2){
      var a=xy[xy.length-2];
      svg+='<polyline points="'+pstr(xy.slice(0,xy.length-1))+'" fill="none" stroke="'+col+'" stroke-width="1.5" stroke-linejoin="round"/>';
      svg+='<line x1="'+a.x.toFixed(1)+'" y1="'+a.y.toFixed(1)+'" x2="'+b.x.toFixed(1)+'" y2="'+b.y.toFixed(1)+'" stroke="'+col+'" stroke-width="1.5" stroke-dasharray="2,2"/>';
      svg+='<circle cx="'+b.x.toFixed(1)+'" cy="'+b.y.toFixed(1)+'" r="2.8" fill="none" stroke="'+col+'" stroke-width="1.5"/>';
    } else {
      svg+='<polyline points="'+pstr(xy)+'" fill="none" stroke="'+col+'" stroke-width="1.5" stroke-linejoin="round"/>';
      svg+='<circle cx="'+b.x.toFixed(1)+'" cy="'+b.y.toFixed(1)+'" r="2.5" fill="'+col+'"/>';
    }
    return svg+'</svg>';
  }'''

# 2) cari ay hesabı (tarayıcı yerel = kullanıcının TR ayı)
GOVDE_OLD = "    var govde='';"
GOVDE_NEW = "    var _n=new Date(); var curAy=_n.getFullYear()+'-'+String(_n.getMonth()+1).padStart(2,'0');\n    var govde='';"

# 3) spark çağrısı + değer satırı: kismi bayrağı + ○
ROW_OLD = r'''      var ok= dpct==null?'':(dpct>0?'▲':'▼');
      govde+='<div style="display:flex;align-items:center;gap:14px;padding:12px 0'+(idx>0?';border-top:0.5px solid var(--cizgi)':'')+'">'
        + '<div style="flex:1;min-width:0"><div style="font-size:13px;margin-bottom:2px">'+esc(c.ad)+'</div>'
        + '<div style="font-size:11px;color:var(--tx-2)">'+seri.length+' ay · '+esc(seri[0].donem)+' → bugün</div></div>'
        + '<div style="width:120px">'+_spark(vals,120,32,c.renk)+'</div>'
        + '<div style="text-align:right;min-width:96px">'
        + '<div class="n" style="font-size:15px">'+c.fmt(cur)+'</div>'
        + '<div style="font-size:11px;color:'+okRenk+'">'+ok+' '+(dpct==null?'—':(Math.abs(dpct)+'% · 12 ay'))+'</div>'
        + '</div></div>';'''
ROW_NEW = r'''      var ok= dpct==null?'':(dpct>0?'▲':'▼');
      var kismi=(seri[seri.length-1].donem===curAy);
      govde+='<div style="display:flex;align-items:center;gap:14px;padding:12px 0'+(idx>0?';border-top:0.5px solid var(--cizgi)':'')+'">'
        + '<div style="flex:1;min-width:0"><div style="font-size:13px;margin-bottom:2px">'+esc(c.ad)+'</div>'
        + '<div style="font-size:11px;color:var(--tx-2)">'+seri.length+' ay · '+esc(seri[0].donem)+' → bugün</div></div>'
        + '<div style="width:120px">'+_spark(vals,120,32,c.renk,kismi)+'</div>'
        + '<div style="text-align:right;min-width:96px">'
        + '<div class="n" style="font-size:15px">'+c.fmt(cur)+(kismi?'<span style="font-size:10px;color:var(--tx-2)" title="kapanmamış ay"> ○</span>':'')+'</div>'
        + '<div style="font-size:11px;color:'+okRenk+'">'+ok+' '+(dpct==null?'—':(Math.abs(dpct)+'% · 12 ay'))+'</div>'
        + '</div></div>';'''

# 4) dipnot
NOTE_OLD = "      + 'Son nokta ölçüldü (kesin); geçmiş aylar rekonstrüksiyon (yaklaşık ~%7). Kaynak: metrik omurgası.</div></div>';"
NOTE_NEW = "      + '○ son nokta = kapanmamış ay (bugün itibarıyla anlık); önceki aylar kapanmış. Geçmiş rekonstrüksiyon ~%7. Kaynak: metrik omurgası.</div></div>';"

for name, old in [('SPARK',SPARK_OLD),('GOVDE',GOVDE_OLD),('ROW',ROW_OLD),('NOTE',NOTE_OLD)]:
    c=b.count(old)
    if c!=1:
        print(f'  ✗ {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
b=b.replace(SPARK_OLD,SPARK_NEW,1).replace(GOVDE_OLD,GOVDE_NEW,1).replace(ROW_OLD,ROW_NEW,1).replace(NOTE_OLD,NOTE_NEW,1)
wr(BIJS,b)
print('  ✅ 4 değişim uygulandı')

r=subprocess.run(['node','--check',BIJS],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
b2=rd(BIJS)
print('  spark partial :', 'function _spark(vals, w, hh, col, partial)' in b2)
print('  curAy         :', 'var curAy=' in b2)
print('  kismi flag    :', 'var kismi=(seri[seri.length-1].donem===curAy)' in b2)
print('  ○ dipnot      :', 'kapanmamış ay (bugün itibarıyla' in b2)
print('\n  ✅ YAMA TAMAM — sırada docker build')
