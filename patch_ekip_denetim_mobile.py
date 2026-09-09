# -*- coding: utf-8 -*-
# EKIP_DENETIM_TASI_V1 (mobil) — Aktivite + Sistem, saha nav'ndan kaldirildi.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "EKIP_DENETIM_TASI_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
OLD = ('    ...(S.isYonetim ? [["rep-aktivite", "📡", "Aktivite"]] : []),\n'
       '    ...((S.isOwner || S.isYonetim) ? [["sistem", "🔧", "Sistem"]] : []) /* HATA_YONETIM_V1 */')
NEW = '    /* EKIP_DENETIM_TASI_V1 — Aktivite + Sistem, Yönetim konsoluna tasindi (saha nav girisi kaldirildi) */'
assert s.count(OLD) == 1, "anchor bulunamadi (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] EKIP_DENETIM_TASI_V1 (mobil)")
