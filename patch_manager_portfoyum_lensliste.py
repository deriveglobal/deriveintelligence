#!/usr/bin/env python3
# MANAGER_PF_LENSLISTE_V1 — lens satırı → gerçek müşteri ucu + güncel shell.
# cd /opt/krb-assessment && python3 patch_manager_portfoyum_lensliste.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SRC="/opt/krb-assessment/server_container.mjs"
BLOCKF="patch_manager_portfoyum_lensliste_endpoint.js"
SHELLF="manager_portfoyum.html"
SHELLD="/opt/krb-assessment/shells/manager_portfoyum.html"
MARKER="MANAGER_PF_LENSLISTE_V1"
ANCHOR='if (method === "GET" && path === "/api/saha/manager-portfoyum/ekran") {'
src=open(SRC,encoding="utf-8").read()
if MARKER in src:
    print("• server zaten yamalı — atlanıyor.")
else:
    n=src.count(ANCHOR)
    if n!=1: print("HATA: anchor %d kez. DUR."%n); sys.exit(1)
    block=open(BLOCKF,encoding="utf-8").read()
    new=src.replace(ANCHOR, block+"\n\n"+ANCHOR, 1)
    shutil.copy(SRC, SRC+".bak_lensliste"); open(SRC,"w",encoding="utf-8").write(new)
    open("/tmp/_ll.mjs","w",encoding="utf-8").write(new)
    r=subprocess.run(["node","--check","/tmp/_ll.mjs"],capture_output=True,text=True)
    if r.returncode!=0:
        shutil.copy(SRC+".bak_lensliste", SRC); print("HATA node --check:\n"+r.stderr); sys.exit(1)
    print("✓ lens-liste ucu eklendi + node --check geçti.")
if os.path.exists(SHELLF):
    os.makedirs(os.path.dirname(SHELLD),exist_ok=True); shutil.copy(SHELLF, SHELLD)
    print("✓ shell güncellendi (lens satırları gerçek müşteriye bağlı).")
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
