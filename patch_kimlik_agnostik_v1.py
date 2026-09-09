#!/usr/bin/env python3
import sys, os, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
MARK = "TENANT_KIMLIK_AGNOSTIK_V1"
s = open(PATH, encoding="utf-8").read()
if MARK in s:
    print("[=] Marker zaten var — patch uygulanmis, cikiliyor (idempotent).")
    sys.exit(0)
LOOKUP = ('  let _tnAgn=null; try { const _rAgn=(await q("SELECT name FROM platform_tenants WHERE id=$1",[T])).rows[0];'
          ' if(_rAgn&&_rAgn.name) _tnAgn=String(_rAgn.name); } catch(_e){} /* ' + MARK + ' */\n')
REPL = [
  ('async function _bolumIcgoruUret(T, q){\n  q = q || query;\n',
   'async function _bolumIcgoruUret(T, q){\n  q = q || query;\n' + LOOKUP),
  ('async function _sahaSesiUret(T, q){ /* SAHA_RAKIP_V6 — kisa rakip aktivitesi, isimli + bu ay vs gecen ay */\n  q = q || query;\n',
   'async function _sahaSesiUret(T, q){ /* SAHA_RAKIP_V6 — kisa rakip aktivitesi, isimli + bu ay vs gecen ay */\n  q = q || query;\n' + LOOKUP),
  ('"Sen KRB adlı lastik toptancısının analistisin.',
   '"Sen " + (_tnAgn||"KRB") + " adlı lastik toptancısının analistisin.'),
  ('"Sen KRB lastik toptancisinin rakip-izleme analistisin.',
   '"Sen " + (_tnAgn||"KRB") + " lastik toptancisinin rakip-izleme analistisin.'),
  ('"Sen KRB adli lastik toptancisinin finans analistisin',
   '"Sen " + ((session&&session.tenantName)||"KRB") + " adli lastik toptancisinin finans analistisin'),
  ('"Sen KRB saha satış zekâsının asistanısın',
   '"Sen " + ((session&&session.tenantName)||"KRB") + " saha satış zekâsının asistanısın'),
]
for i, (old, new) in enumerate(REPL, 1):
    c = s.count(old)
    if c != 1:
        print(f"[!] HATA: site {i} anchor {c} kez bulundu (1 olmali). Patch iptal, dosya DEGISMEDI.")
        print(f"    anchor bas: {old[:60]!r}")
        sys.exit(1)
bak = PATH + ".bak_kimlik_agnostik"
shutil.copy2(PATH, bak)
print(f"[+] Yedek: {bak}")
for i, (old, new) in enumerate(REPL, 1):
    s = s.replace(old, new, 1)
    print(f"[+] site {i} uygulandi.")
open(PATH, "w", encoding="utf-8").write(s)
print(f"[OK] {MARK} uygulandi. node --check calistir.")
