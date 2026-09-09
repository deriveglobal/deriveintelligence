# -*- coding: utf-8 -*-
# FINANS_IZIN_V1 — Yonetim konsolu Izinler matrisine "Finans Odasi" alt-araci (intelligence modulu).
#   modTools("intelligence") otomatik toplar -> DEFAULTS.intelligence.manager/admin ONU DA kapsar
#   (analyst/viewer haric). Boylece manager+admin varsayilan; digerleri elle grant.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "FINANS_IZIN_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
OLD = '["price-list", "Fiyat Listesi"]]]\n      ],'
NEW = ('["price-list", "Fiyat Listesi"]]],\n'
       '        ["Odalar", [["finansodasi", "Finans Odası"]]]  /* FINANS_IZIN_V1 */\n'
       '      ],')
assert s.count(OLD) == 1, "anchor bulunamadi (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] FINANS_IZIN_V1 (matris)")
