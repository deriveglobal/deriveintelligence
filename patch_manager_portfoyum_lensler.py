#!/usr/bin/env python3
# MANAGER_PF_LENSLER_V1 — 7 lens gerçek veri ucu + güncel shell (lensler canlı).
# Çalıştırma: cd /opt/krb-assessment && python3 patch_manager_portfoyum_lensler.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SRC="/opt/krb-assessment/server_container.mjs"
BLOCKF="patch_manager_portfoyum_lensler_endpoint.js"
SHELLF="manager_portfoyum.html"
SHELLD="/opt/krb-assessment/shells/manager_portfoyum.html"
MARKER="MANAGER_PF_LENSLER_V1"
ANCHOR='if (method === "GET" && path === "/api/saha/manager-portfoyum/ekran") {'

src=open(SRC,encoding="utf-8").read()
if MARKER in src:
    print("• server zaten yamalı (%s) — atlanıyor."%MARKER)
else:
    n=src.count(ANCHOR)
    if n!=1:
        print("HATA: anchor %d kez (1 bekleniyordu). MANAGER_PORTFOYUM_V1 uygulandı mı? DUR."%n); sys.exit(1)
    block=open(BLOCKF,encoding="utf-8").read()
    new=src.replace(ANCHOR, block+"\n\n"+ANCHOR, 1)
    shutil.copy(SRC, SRC+".bak_mpflensler")
    open(SRC,"w",encoding="utf-8").write(new)
    open("/tmp/_mpflens_chk.mjs","w",encoding="utf-8").write(new)
    r=subprocess.run(["node","--check","/tmp/_mpflens_chk.mjs"],capture_output=True,text=True)
    if r.returncode!=0:
        shutil.copy(SRC+".bak_mpflensler", SRC)
        print("HATA: node --check FAIL — geri alındı.\n"+r.stderr); sys.exit(1)
    print("✓ lensler ucu eklendi + node --check geçti.")

if os.path.exists(SHELLF):
    os.makedirs(os.path.dirname(SHELLD),exist_ok=True)
    shutil.copy(SHELLF, SHELLD)
    print("✓ shell güncellendi (lensler canlı):", SHELLD)
else:
    print("UYARI: %s yok."%SHELLF)
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
