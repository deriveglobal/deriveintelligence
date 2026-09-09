# -*- coding: utf-8 -*-
# BUGUN_KATLA_FOLD_V1 — mobil Bugun bolumleri VARSAYILAN KAPALI baslasin (kullanici acar).
#   secBlock icindeki 'acik' varsayilanini kapaliya cevirir; hicbir cagri acik istemedigi
#   icin tum bolumler kapali gelir. Mevcut { kapali:true } opsiyonlari zararsiz kalir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "BUGUN_KATLA_FOLD_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = "      const acik = !(opts && opts.kapali);"
NEW = "      const acik = !!(opts && opts.acik);  /* BUGUN_KATLA_FOLD_V1: hepsi kapali baslasin */"
assert s.count(OLD) == 1, "anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_KATLA_FOLD_V1")
