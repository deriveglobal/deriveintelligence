#!/usr/bin/env python3
# omurga_73-fix3 — kokpit-data SQL tip guvenligi: tenant_id=$1::uuid -> tenant_id::text=$1 (SADECE bu blokta) + join ::text.
import shutil, subprocess, sys
S="/opt/krb-assessment/server_container.mjs"
srv=open(S,encoding="utf-8").read()

p = srv.index('url.pathname === "/api/bi/kokpit-data"')
a = srv.rindex('if (', 0, p)
kd = srv.index('[kokpit-data]', a)
ret = srv.index('return;', kd)
b = srv.index('}', ret) + 1
block = srv[a:b]

n1 = block.count('tenant_id=$1::uuid')
n2 = block.count('a.tenant_id=f.tenant_id')
if n1==0 and 'tenant_id::text=$1' in block:
    sys.exit("zaten uygulanmis gibi (tenant_id::text=$1 var). elle bak.")
fixed = block.replace('tenant_id=$1::uuid','tenant_id::text=$1').replace('a.tenant_id=f.tenant_id','a.tenant_id::text=f.tenant_id::text')
srv = srv[:a] + fixed + srv[b:]
print(f"degistirilen: tenant_id=$1::uuid x{n1}, join x{n2}")

shutil.copy2(S,S+".k4.bak")
open(S,"w",encoding="utf-8").write(srv)
try:
    chk=subprocess.run(["node","--check",S],capture_output=True,text=True)
    if chk.returncode!=0:
        shutil.copy2(S+".k4.bak",S); sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n"+chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .k4.bak)")
print("OK: kokpit-data tip-guvenli. docker build + compose up.")
