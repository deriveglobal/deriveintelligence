#!/usr/bin/env python3
# YONPORTFOY_TAB_FIX_V1 — template literal icine sizan /* YONPORTFOY_ODA_V1 */ yorumunu nav'dan kaldirir.
# Oda marker'i (// YONPORTFOY_ODA_V1) kalir. Idempotent + .bak + node --check + rollback. TEK build.
# KULLANIM: /opt/krb-assessment/ icine koy →
#   cd /opt/krb-assessment && python3 patch_yonportfoy_tabfix.py \
#     && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
BI='/opt/krb-assessment/shells/bi.js'
LEAK='<button class="vmo-tab" data-dept="yonportfoy" style="--c:#3fb9a2"><span>🧭</span> Yönetici Portföy</button>\' : ""}  /* YONPORTFOY_ODA_V1 */'
FIXED='<button class="vmo-tab" data-dept="yonportfoy" style="--c:#3fb9a2"><span>🧭</span> Yönetici Portföy</button>\' : ""}'
def nc(t):
    for ext in ("mjs","cjs"):
        p="/tmp/_ynf."+ext; open(p,"w",encoding="utf-8").write(t)
        if subprocess.run(["node","--check",p],capture_output=True,text=True).returncode==0: return True,""
        e=subprocess.run(["node","--check",p],capture_output=True,text=True).stderr
    return False,e
if not os.path.exists(BI): print("HATA yok:",BI); sys.exit(1)
src=open(BI,encoding="utf-8").read()
if LEAK not in src:
    print("• sizan yorum yok (zaten duzelmis), atlandi."); sys.exit(0)
src=src.replace(LEAK,FIXED,1)
ok,err=nc(src)
if not ok: print("HATA node --check:\n"+err); sys.exit(1)
shutil.copy(BI,BI+".bak_yntabfix"); open(BI,"w",encoding="utf-8").write(src)
print("✓ sizan yorum kaldirildi (bi.js nav).")
print("\nSimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
