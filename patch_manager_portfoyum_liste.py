#!/usr/bin/env python3
# MANAGER_PF_LISTE_V1 — drill liste ucunu ekler + güncel shell'i yeniden yerleştirir.
# Çalıştırma: cd /opt/krb-assessment && python3 patch_manager_portfoyum_liste.py
import sys, subprocess, shutil, os

SRC    = "/opt/krb-assessment/server_container.mjs"
BLOCKF = "patch_manager_portfoyum_liste_endpoint.js"
SHELLF = "manager_portfoyum.html"
SHELLD = "/opt/krb-assessment/shells/manager_portfoyum.html"
MARKER = "MANAGER_PF_LISTE_V1"
ANCHOR = 'if (method === "GET" && path === "/api/saha/manager-portfoyum/ekran") {'

src = open(SRC, encoding="utf-8").read()
if MARKER in src:
    print("• server zaten yamalı (%s) — atlanıyor." % MARKER)
else:
    n = src.count(ANCHOR)
    if n != 1:
        print("HATA: anchor %d kez (1 bekleniyordu). MANAGER_PORTFOYUM_V1 uygulandı mı? DUR." % n); sys.exit(1)
    block = open(BLOCKF, encoding="utf-8").read()
    new = src.replace(ANCHOR, block + "\n\n" + ANCHOR, 1)
    shutil.copy(SRC, SRC + ".bak_mpfliste")
    open(SRC, "w", encoding="utf-8").write(new)
    open("/tmp/_mpfl_chk.mjs", "w", encoding="utf-8").write(new)
    r = subprocess.run(["node", "--check", "/tmp/_mpfl_chk.mjs"], capture_output=True, text=True)
    if r.returncode != 0:
        shutil.copy(SRC + ".bak_mpfliste", SRC)
        print("HATA: node --check FAIL — geri alındı.\n" + r.stderr); sys.exit(1)
    print("✓ liste ucu eklendi + node --check geçti.")

if os.path.exists(SHELLF):
    os.makedirs(os.path.dirname(SHELLD), exist_ok=True)
    shutil.copy(SHELLF, SHELLD)
    print("✓ shell güncellendi (tıklama gerçek listeye bağlı):", SHELLD)
else:
    print("UYARI: %s yok — shell'i elle güncelle." % SHELLF)

print("\nŞimdi:  docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
print("Doğrula: docker exec krb-assessment grep -c %s /app/server.mjs" % MARKER)
