# -*- coding: utf-8 -*-
# IZIN_ROLDEF_SH_V1 — Rapor alt-sekme kapisi:
#   admin → hepsi (bypass); kayit yoksa grandfather YERINE ROL VARSAYILANI
#   (rep → yalniz rotam; manager → üçü de). Ayni _rTabOk satiri dk+mob.
import sys
F = sys.argv[1]
s = open(F, encoding="utf-8").read()
if "IZIN_ROLDEF_SH_V1" in s:
    print("[skip] zaten yamali:", F); sys.exit(0)
o = '  const _rTabOk = (id) => !_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : true);'
n = '  const _rTabOk = (id) => (S.role === "admin") ? true : (!_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : (S.role === "rep" ? id === "rotam" : true)));  /* IZIN_ROLDEF_SH_V1 */'
assert s.count(o) == 1, "anchor=%d in %s" % (s.count(o), F)
s = s.replace(o, n, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] IZIN_ROLDEF_SH_V1:", F)
