# -*- coding: utf-8 -*-
# MEMNUNIYET_GATE_SRV_V1 — SAHA_DEPT_MAP'e /api/saha/nabiz-ozet -> ["memnuniyet"].
#   nabiz-ozet zaten requireSahaAccess(["manager","admin"]) istiyor (rep giremez). Bu ek
#   _enforceSahaDept ile: admin bypass; manager ancak "memnuniyet" dept'i varsa (ya da bos dept
#   fallback) erisir -> matris toggle'i manager erisimini GERCEKTEN yonetir (kozmetik degil).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MEMNUNIYET_GATE_SRV_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
OLD = ('"/api/saha/musteri-aksiyon": ["kapsam", "musteriler", "ziyaretler", "rapor"]\n'
       '  };')
NEW = ('"/api/saha/musteri-aksiyon": ["kapsam", "musteriler", "ziyaretler", "rapor"],\n'
       '    "/api/saha/nabiz-ozet": ["memnuniyet"]  /* MEMNUNIYET_GATE_SRV_V1 */\n'
       '  };')
assert s.count(OLD) == 1, "anchor bulunamadi (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] MEMNUNIYET_GATE_SRV_V1 (SAHA_DEPT_MAP += nabiz-ozet)")
