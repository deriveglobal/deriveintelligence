#!/usr/bin/env python3
# OMURGA 32 — KENDİNİ-KAYDET: konteyner her açılışında footprint (deploy-yöntemi bağımsız).
# server.mjs: fs importa readFileSync + footprintOnBoot() + listen callback'te çağrı. try/catch, boot'u bloklamaz.
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
s=rd(SRV)

if 'footprintOnBoot' in s:
    print('  ⏭ zaten yamalı'); sys.exit(0)

# 1) fs importuna readFileSync ekle
IMP_OLD = 'import { createReadStream } from "node:fs";'
IMP_NEW = 'import { createReadStream, readFileSync } from "node:fs";'

# 2) footprintOnBoot fonksiyonu — createServer'dan önce
FUNC_ANCHOR = 'createServer(async (request, response) => {'
FUNC_NEW = r'''// ⭐ KENDİNİ-KAYDET (omurga_32): konteyner her açılışında yetenek defterini tazele.
// deploy NASIL yapılırsa yapılsın (deploy.sh, çıplak docker, herhangi) restart → bu çalışır.
// İnsan hafızasına GÜVENMEZ. try/catch: boot'u ASLA bloklamaz.
async function footprintOnBoot() {
  try { await query("SELECT yetenek_tara()"); } catch (e) { console.error("[footprint] yetenek_tara:", e && e.message); }
  try {
    const t0 = new Date();
    const src = readFileSync("/app/server.mjs", "utf8");
    const eps = [...new Set((src.match(/url\.pathname === '(\/api\/[^']+)'/g) || [])
      .map(m => (m.match(/'(\/api\/[^']+)'/) || [])[1]).filter(Boolean))];
    for (const p of eps) {
      await query("INSERT INTO bi_yetenek(ad,tur,durum,parmak_izi,son_gorulme) VALUES($1,'endpoint','tanimsiz',md5($1),now()) ON CONFLICT (ad,tur) DO UPDATE SET son_gorulme=now()", [p]);
    }
    await query("UPDATE bi_yetenek SET durum='kayip', aktif=false WHERE tur='endpoint' AND durum<>'kayip' AND son_gorulme < $1", [t0]);
    await query("INSERT INTO bi_deploy_log(aciklama,yetenek_ozet) SELECT 'boot self-register', (SELECT jsonb_object_agg(tur,c) FROM (SELECT tur,count(*) c FROM bi_yetenek GROUP BY tur) x)");
    console.log("[footprint] boot self-register OK — " + eps.length + " endpoint defterde");
  } catch (e) { console.error("[footprint] endpoint:", e && e.message); }
}

createServer(async (request, response) => {'''

# 3) listen callback'te çağrı
LISTEN_OLD = '}).listen(port, async () => {'
LISTEN_NEW = '}).listen(port, async () => {\n  footprintOnBoot().catch(e => console.error("[footprint] boot:", e && e.message));'

for name, old in [('IMP',IMP_OLD),('FUNC',FUNC_ANCHOR),('LISTEN',LISTEN_OLD)]:
    c=s.count(old)
    if c!=1:
        print(f'  ✗ {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)

s=s.replace(IMP_OLD,IMP_NEW,1).replace(FUNC_ANCHOR,FUNC_NEW,1).replace(LISTEN_OLD,LISTEN_NEW,1)
wr(SRV,s)
print('  ✅ import + footprintOnBoot + listen çağrısı eklendi')

r=subprocess.run(['node','--check',SRV],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
s2=rd(SRV)
print('  readFileSync :', 'createReadStream, readFileSync' in s2)
print('  func         :', 'async function footprintOnBoot()' in s2)
print('  boot çağrısı :', 'footprintOnBoot().catch' in s2)
print('\n  ✅ YAMA TAMAM — bir kez deploy et; sonra footprint HER açılışta otomatik (hatırlamaya gerek yok)')
