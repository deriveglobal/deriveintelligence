# -*- coding: utf-8 -*-
# SEKME_CAP_MOB_V1 (saha.js) — mobil sekme kapilari. etki/portfoy/pipeline/pazar artik _rNEW (gateable).
#   ⚠ AYRIK ANAHTAR: _rHasNew flip'i ORIJINAL sette (_rHASNEW=ciro/risk/rotam/kapsam) hesaplanir -> backfill'in
#   etki eklemesi flip'i DEGISTIRMEZ (rol-fallback'a dayanan yonetici ciro/risk/rotam KAYBETMEZ). not-hasNew:
#   yeni 4 sekme daima gorunur (bugunku always-on), eski sekmeler rep->rotam / mgr->hepsi. hasNew: dept.includes.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "SEKME_CAP_MOB_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

RNEW_OLD = '  const _rNEW = ["ciro", "risk", "rotam", "kapsam"], _rHasNew = _rd.some(d => _rNEW.includes(d));  /* KAPSAM_MOB_V1 */'
assert s.count(RNEW_OLD) == 1, "_rNEW anchor=%d" % s.count(RNEW_OLD)
s = s.replace(RNEW_OLD, '  const _rNEW = ["ciro", "risk", "rotam", "kapsam", "etki", "portfoy", "pipeline", "pazar"], _rHASNEW = ["ciro", "risk", "rotam", "kapsam"], _rHasNew = _rd.some(d => _rHASNEW.includes(d));  /* SEKME_CAP_MOB_V1 — flip anahtari orijinal set (backfill flip etmez) */  /* KAPSAM_MOB_V1 */', 1)

TABOK_OLD = '  const _rTabOk = (id) => (S.role === "admin") ? true : (!_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : (S.role === "rep" ? id === "rotam" : true)));  /* IZIN_ROLDEF_SH_V1 */'
assert s.count(TABOK_OLD) == 1, "_rTabOk anchor=%d" % s.count(TABOK_OLD)
s = s.replace(TABOK_OLD, '  const _rTabOk = (id) => (S.role === "admin") ? true : (!_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : (["etki", "portfoy", "pipeline", "pazar"].includes(id) ? true : (S.role === "rep" ? id === "rotam" : true))));  /* SEKME_CAP_MOB_V1 */  /* IZIN_ROLDEF_SH_V1 */', 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SEKME_CAP_MOB_V1 (saha.js) — ayrik-anahtar _rNEW/_rHASNEW + _rTabOk")
