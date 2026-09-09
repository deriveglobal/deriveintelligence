# -*- coding: utf-8 -*-
# SEKME_CAP_FIX_V1 (saha_desktop.js) — flip anahtari _rHasNew -> _rd.length (deny-by-default). On kosul: SEKME_CAP_DK_V1.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "SEKME_CAP_FIX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SEKME_CAP_DK_V1" in s, "once SEKME_CAP_DK_V1 olmali"

OLD = '  const _rTabOk = (id) => (S.role === "admin") ? true : (!_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : (["etki", "portfoy", "pipeline", "pazar"].includes(id) ? true : (S.role === "rep" ? id === "rotam" : true))));  /* SEKME_CAP_DK_V1 */  /* IZIN_ROLDEF_SH_V1 */'
assert s.count(OLD) == 1, "_rTabOk anchor=%d" % s.count(OLD)
NEW = '  const _rTabOk = (id) => (S.role === "admin") ? true : (!_rNEW.includes(id) ? true : (_rd.length ? _rd.includes(id) : (["etki", "portfoy", "pipeline", "pazar"].includes(id) ? true : (S.role === "rep" ? id === "rotam" : true))));  /* SEKME_CAP_FIX_V1 — deny-by-default */  /* SEKME_CAP_DK_V1 */  /* IZIN_ROLDEF_SH_V1 */'
s = s.replace(OLD, NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SEKME_CAP_FIX_V1 (saha_desktop.js) — flip anahtari _rd.length")
