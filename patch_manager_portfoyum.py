#!/usr/bin/env python3
# MANAGER_PORTFOYUM_V1 — idempotent patch: endpoint bloğunu server_container.mjs'e ekler + shell'i yerleştirir.
# Çalıştırma (sunucuda, /opt/krb-assessment içinde, 3 dosya yan yana):
#   cd /opt/krb-assessment
#   python3 patch_manager_portfoyum.py
# Kurallar: benzersiz anchor + assert count==1 + marker (idempotent) + .bak + node --check + rollback.
import sys, subprocess, shutil, os

SRC    = "/opt/krb-assessment/server_container.mjs"
BLOCKF = "patch_manager_portfoyum_endpoint.js"          # yan dosya
SHELLF = "manager_portfoyum.html"                        # yan dosya
SHELLD = "/opt/krb-assessment/shells/manager_portfoyum.html"
MARKER = "MANAGER_PORTFOYUM_V1"
ANCHOR = 'if (method === "GET" && path === "/api/saha/musteriler") {'

if not os.path.exists(SRC):
    print("HATA: bulunamadi:", SRC); sys.exit(1)
src = open(SRC, encoding="utf-8").read()

# 1) idempotent — zaten uygulandiysa cik
if MARKER in src:
    print("• server zaten yamalı (%s) — atlanıyor." % MARKER)
else:
    n = src.count(ANCHOR)
    if n != 1:
        print("HATA: anchor %d kez bulundu (1 bekleniyordu). DUR, elle bak." % n); sys.exit(1)
    block = open(BLOCKF, encoding="utf-8").read()
    new = src.replace(ANCHOR, block + "\n\n    " + ANCHOR, 1)
    shutil.copy(SRC, SRC + ".bak_managerpf")
    open(SRC, "w", encoding="utf-8").write(new)
    # node --check (mjs kopya)
    open("/tmp/_mpf_chk.mjs", "w", encoding="utf-8").write(new)
    r = subprocess.run(["node", "--check", "/tmp/_mpf_chk.mjs"], capture_output=True, text=True)
    if r.returncode != 0:
        shutil.copy(SRC + ".bak_managerpf", SRC)
        print("HATA: node --check FAIL — geri alındı.\n" + r.stderr); sys.exit(1)
    print("✓ server_container.mjs yamalandı + node --check geçti (.bak_managerpf).")

# 2) shell'i yerleştir
if os.path.exists(SHELLF):
    os.makedirs(os.path.dirname(SHELLD), exist_ok=True)
    shutil.copy(SHELLF, SHELLD)
    print("✓ shell yerleştirildi:", SHELLD)
else:
    print("UYARI: %s yok — shell'i /opt/krb-assessment/shells/ altına elle koy." % SHELLF)

print("\nBİTTİ. Şimdi:  docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
print("Doğrula:      docker exec krb-assessment grep -c %s /app/server.mjs   (>=1 olmalı)" % MARKER)
