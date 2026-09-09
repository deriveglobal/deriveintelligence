#!/usr/bin/env python3
# OMURGA 41 — drill Marj satırına % ekle (nominal TL + marj%). bi.js UI.
import sys, subprocess
BIJS='/opt/krb-assessment/shells/bi.js'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
b=rd(BIJS)

if 'ciroToplam' in b:
    print('  ⏭ zaten yamalı'); sys.exit(0)

# 1) ciro toplamını hesapla (marj% için payda)
E1_OLD = "    var hh='';\n    metr.forEach(function(m,i){"
E1_NEW = "    var ciroToplam=pts.reduce(function(a,p){return a+(p.ciro||0);},0);\n    var hh='';\n    metr.forEach(function(m,i){"

# 2) Marj satırında % göster
E2_OLD = "        + '<div class=\"n\" style=\"flex:1;text-align:right;font-size:13px\">'+m.fmt(cur)+' <span style=\"font-size:11px;color:'+okc+'\">'+oki+' '+(dpct==null?'—':Math.abs(dpct)+'%')+'</span></div></div>';"
E2_NEW = "        + '<div class=\"n\" style=\"flex:1;text-align:right;font-size:13px\">'+m.fmt(cur)+(m.fld==='marj'&&cur!=null&&ciroToplam?' <span style=\"color:var(--tx-2);font-size:11px\">(%'+Math.round(100*cur/ciroToplam)+')</span>':'')+' <span style=\"font-size:11px;color:'+okc+'\">'+oki+' '+(dpct==null?'—':Math.abs(dpct)+'%')+'</span></div></div>';"

for name, old in [('E1',E1_OLD),('E2',E2_OLD)]:
    c=b.count(old)
    if c!=1:
        print(f'  ✗ {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
b=b.replace(E1_OLD,E1_NEW,1).replace(E2_OLD,E2_NEW,1)
wr(BIJS,b)
print('  ✅ marj% eklendi')

r=subprocess.run(['node','--check',BIJS],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
b2=rd(BIJS)
print('  ciroToplam :', 'var ciroToplam=' in b2)
print("  marj% :", "m.fld==='marj'&&cur!=null&&ciroToplam" in b2)
print('\n  ✅ YAMA TAMAM — docker build; Marj satırı artık TL + %')
