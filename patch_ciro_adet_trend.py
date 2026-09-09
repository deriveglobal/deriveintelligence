#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys, shutil, time
f = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/kokpit_iki.html"
s = open(f, encoding="utf-8").read()
orig = s
anchor = 'document.getElementById("a1title").textContent="Şirket · tek kimlik";\n  const bu=isBuAy();'
helper = anchor + '''
  /* CIRO_ADET_TREND_V1 — Ciro/Adet kartina GY(YoY)+geçen ay(MoM) chip; kaynak ciro_donem_pano (§4) */
  const _tsrc = bu ? (UD.canli||{}) : (UD.sirket||{});
  const _tfmt = (v)=> v==null?null:((v>0?'+':'')+(Math.abs(v)>=10?Math.round(v):Math.round(v*10)/10)+'%');
  const _tcol = (t)=> t==='up'?'#34d399':t==='down'?'#f87171':'var(--mut)';
  const _tarr = (t)=> t==='up'?'▲':t==='down'?'▼':'—';
  const _tsgnA = (v)=> v==null?'—':(v>0?'▲':v<0?'▼':'—');
  const _tsgnC = (v)=> v==null?'var(--mut)':(v>0?'#34d399':v<0?'#f87171':'var(--mut)');
  const _trendChip = (p)=> p.length? `<div class="cok-trend" style="font-size:11px;margin-top:3px;letter-spacing:.2px;line-height:1.3">${p.join(' · ')}</div>`:'';
  const _ciroTrend = (()=>{ const y=_tsrc.yoy_pct,m=_tsrc.mom_pct,tr=_tsrc.trend,p=[]; if(y!=null)p.push(`<span style="color:${_tcol(tr)}">${_tarr(tr)} GY ${_tfmt(y)}</span>`); if(m!=null)p.push(`<span style="color:var(--mut)">geçen ay ${_tfmt(m)}</span>`); return _trendChip(p); })();
  const _adetTrend = (()=>{ const a=_tsrc.adet_yoy_pct,p=[]; if(a!=null)p.push(`<span style="color:${_tsgnC(a)}">${_tsgnA(a)} GY ${_tfmt(a)}</span>`); return _trendChip(p); })();'''
if s.count(anchor) != 1:
    print("ABORT: a1title/bu capa =", s.count(anchor)); sys.exit(1)
s = s.replace(anchor, helper)
c_old = 'M₺</small></div><div class="d">tüm kalemler'
c_new = 'M₺</small></div>${_ciroTrend}<div class="d">tüm kalemler'
if s.count(c_old) != 1:
    print("ABORT: ciro capa =", s.count(c_old)); sys.exit(1)
s = s.replace(c_old, c_new)
a_old = 'bin</small></div><div class="d">yalnız lastik adedi'
a_new = 'bin</small></div>${_adetTrend}<div class="d">yalnız lastik adedi'
if s.count(a_old) != 1:
    print("ABORT: adet capa =", s.count(a_old)); sys.exit(1)
s = s.replace(a_old, a_new)
shutil.copy2(f, f + ".bak_trend_" + str(int(time.time())))
open(f, "w", encoding="utf-8").write(s)
print("OK: CIRO_ADET_TREND_V1 — 3 yerlestirme, +%d byte, yedek .bak_trend_*" % (len(s)-len(orig)))
