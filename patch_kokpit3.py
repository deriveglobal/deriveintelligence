#!/usr/bin/env python3
# omurga_73-fix2 — kokpit-data auth: getSessionUser -> requireModuleAccess (tenant cozumu icgoru ile ayni).
import shutil, subprocess, sys
S="/opt/krb-assessment/server_container.mjs"
srv=open(S,encoding="utf-8").read()

OLD='''      const session = await getSessionUser(request);
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }'''
NEW='''      const session = await requireModuleAccess(request, "intelligence");
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }'''

if 'requireModuleAccess(request, "intelligence")' in srv and 'kokpit-data' in srv and OLD not in srv:
    print("zaten uygulanmis olabilir — kontrol et")
if OLD not in srv:
    sys.exit("HATA: kokpit-data getSessionUser blogu bulunamadi (elle bak)")
srv=srv.replace(OLD,NEW,1)

shutil.copy2(S,S+".k3.bak")
open(S,"w",encoding="utf-8").write(srv)
try:
    chk=subprocess.run(["node","--check",S],capture_output=True,text=True)
    if chk.returncode!=0:
        shutil.copy2(S+".k3.bak",S); sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n"+chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .k3.bak)")
print("OK: kokpit-data auth = requireModuleAccess(intelligence). docker build + compose up.")
