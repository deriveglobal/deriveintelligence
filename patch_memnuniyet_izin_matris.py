# -*- coding: utf-8 -*-
# MEMNUNIYET_IZIN_V1 — Izinler matrisine "Memnuniyet" alt-araci (saha modulu, Yönetim & Analiz grubu,
#   rep-aktivite yaninda). dept key = memnuniyet. admin = modTools ile otomatik kapsar; manager default'a
#   EKLENMEZ (rep-aktivite gibi) — owner elle grant eder / backfill korur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "MEMNUNIYET_IZIN_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
OLD = '["rep-aktivite", "Aktivite"]]]'
NEW = '["rep-aktivite", "Aktivite"], ["memnuniyet", "Memnuniyet"]]]  /* MEMNUNIYET_IZIN_V1 */'
assert s.count(OLD) == 1, "anchor bulunamadi (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] MEMNUNIYET_IZIN_V1 (matris)")
