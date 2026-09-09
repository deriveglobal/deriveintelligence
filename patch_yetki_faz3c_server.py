# -*- coding: utf-8 -*-
# YETKI_FAZ3C (server) — veri kapsamini AGREGAT raporlara genislet: Kapsam + Portfoy + Saha ROI (ziyaret-etki) + kapsam-export.
#   Bugun: rol==="rep" -> m.sorumlu_rep=self; yonetici -> filtresiz (hepsi). Faz 3c: yonetici dalina _sahaScopeSql ekle.
#   OPT-IN: scope kendi/bolge/bolum -> filtre; tumu/ayarsiz/admin -> "" (bugunku davranis, regresyon yok).
#   4 uc ayni deseni paylasir (alias 'm' = saha_musteri); replace ile dordune birden. On kosul: YETKI_FAZ3A (_sahaScopeSql).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ3C" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "_sahaScopeSql" in s, "once YETKI_FAZ3A (_sahaScopeSql) olmali"

ANCH = '      if (rol === "rep") { p.push(uid); repF = ` AND m.sorumlu_rep::text=$${p.length}::text`; }'
n = s.count(ANCH)
assert n == 4, "rep-filtre anchor=%d (beklenen 4)" % n
REPL = ANCH + '\n      else { repF = _sahaScopeSql(session, p, "m"); }  /* YETKI_FAZ3C — yonetici veri kapsami (kendi/bolge/bolum; tumu/admin -> filtre yok) */'
s = s.replace(ANCH, REPL)  # 4 site

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ3C (server) — Kapsam/Portfoy/Saha ROI/kapsam-export yoneticide _sahaScopeSql (4 uc)")
