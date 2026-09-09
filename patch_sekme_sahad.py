# -*- coding: utf-8 -*-
# SEKME_CAP_DK_V1 (saha_desktop.js) — masaustu sekme kapilari. etki/portfoy/pipeline/pazar _rNEW'e (gateable).
#   ⚠ AYRIK ANAHTAR: _rHasNew flip'i ORIJINAL desktop set (_rHASNEW=ciro/risk/rotam) uzerinden -> backfill flip etmez.
#   kapsam masaustunde isMgr-sarmali + _rNEW DISI birakildi (davranis korunur: mgr'da daima, rep'te hic).
#   not-hasNew: yeni 4 sekme daima; eski rep->rotam / mgr->hepsi. hasNew: dept.includes.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "SEKME_CAP_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

RNEW_OLD = '  const _rNEW = ["ciro", "risk", "rotam"], _rHasNew = _rd.some(d => _rNEW.includes(d));'
assert s.count(RNEW_OLD) == 1, "_rNEW anchor=%d" % s.count(RNEW_OLD)
s = s.replace(RNEW_OLD, '  const _rNEW = ["ciro", "risk", "rotam", "etki", "portfoy", "pipeline", "pazar"], _rHASNEW = ["ciro", "risk", "rotam"], _rHasNew = _rd.some(d => _rHASNEW.includes(d));  /* SEKME_CAP_DK_V1 — flip anahtari orijinal set */', 1)

TABOK_OLD = '  const _rTabOk = (id) => (S.role === "admin") ? true : (!_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : (S.role === "rep" ? id === "rotam" : true)));  /* IZIN_ROLDEF_SH_V1 */'
assert s.count(TABOK_OLD) == 1, "_rTabOk anchor=%d" % s.count(TABOK_OLD)
s = s.replace(TABOK_OLD, '  const _rTabOk = (id) => (S.role === "admin") ? true : (!_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : (["etki", "portfoy", "pipeline", "pazar"].includes(id) ? true : (S.role === "rep" ? id === "rotam" : true))));  /* SEKME_CAP_DK_V1 */  /* IZIN_ROLDEF_SH_V1 */', 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SEKME_CAP_DK_V1 (saha_desktop.js) — ayrik-anahtar _rNEW/_rHASNEW + _rTabOk (kapsam korundu)")
