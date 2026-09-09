#!/usr/bin/env python3
# MANAGER_PF_LISTE_FIX — liste ucundaki filtre bug'ı: f.* → mk.*/sk.* (CTE kendi adına referans veremez).
# Çalıştırma: cd /opt/krb-assessment && python3 patch_mpf_liste_fix.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SRC = "/opt/krb-assessment/server_container.mjs"
src = open(SRC, encoding="utf-8").read()

OLD_KOVA = 'filt = "f.segment = $"'
OLD_REP  = 'filt = "f.sorumlu_rep::text = $"'
NEW_KOVA = 'filt = "sk.segment = $"'
NEW_REP  = 'filt = "mk.sorumlu_rep::text = $"'

if OLD_KOVA not in src and OLD_REP not in src:
    if NEW_REP in src:
        print("• zaten düzeltilmiş — atlanıyor."); sys.exit(0)
    print("HATA: beklenen satırlar bulunamadı (ne eski ne yeni). DUR."); sys.exit(1)

new = src.replace(OLD_KOVA, NEW_KOVA).replace(OLD_REP, NEW_REP)
shutil.copy(SRC, SRC + ".bak_mpflistefix")
open(SRC, "w", encoding="utf-8").write(new)
open("/tmp/_fix.mjs", "w", encoding="utf-8").write(new)
r = subprocess.run(["node", "--check", "/tmp/_fix.mjs"], capture_output=True, text=True)
if r.returncode != 0:
    shutil.copy(SRC + ".bak_mpflistefix", SRC)
    print("HATA: node --check FAIL — geri alındı.\n" + r.stderr); sys.exit(1)
print("✓ liste filtresi düzeltildi (mk.sorumlu_rep / sk.segment) + node --check geçti.")
print("Şimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
