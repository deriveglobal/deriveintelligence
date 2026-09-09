#!/usr/bin/env python3
# MANAGER_PF_LENS_YOY_FIX — DGY/GYEND'i lensler bloğunun scope'una ekler (yanlış yere düşmüştü).
# cd /opt/krb-assessment && python3 patch_lens_yoy_fix.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil
SRC="/opt/krb-assessment/server_container.mjs"
src=open(SRC,encoding="utf-8").read()

ANCHOR = "  const sube = (await query("
DECL = '''  const DGY = donem === "buay" ? "date_trunc('month',CURRENT_DATE) - INTERVAL '1 year'"
            : donem === "3ay"  ? "CURRENT_DATE - INTERVAL '15 months'"
            : donem === "6ay"  ? "CURRENT_DATE - INTERVAL '18 months'"
            : donem === "ytd"  ? "date_trunc('year',CURRENT_DATE) - INTERVAL '1 year'"
            :                    "CURRENT_DATE - INTERVAL '24 months'";
  const GYEND = "CURRENT_DATE - INTERVAL '1 year'";
'''

if src.count("const DGY") >= 2:
    print("• zaten düzeltilmiş (DGY lensler scope'unda).")
elif ANCHOR not in src:
    print("HATA: 'const sube' bulunamadı — DUR."); sys.exit(1)
else:
    src = src.replace(ANCHOR, DECL + ANCHOR, 1)
    shutil.copy(SRC, SRC+".bak_yoyfix"); open(SRC,"w",encoding="utf-8").write(src)
    open("/tmp/_yoyf.mjs","w",encoding="utf-8").write(src)
    r=subprocess.run(["node","--check","/tmp/_yoyf.mjs"],capture_output=True,text=True)
    if r.returncode!=0:
        shutil.copy(SRC+".bak_yoyfix", SRC); print("HATA node --check:\n"+r.stderr); sys.exit(1)
    print("✓ DGY/GYEND lensler scope'una eklendi + node --check geçti.")
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
