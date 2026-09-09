# -*- coding: utf-8 -*-
# FINANS_GATE_FIX_V1 — bi.js satir 82: /* FINANS_GATE_V1 */ yorumu nav TEMPLATE LITERAL
#   icinde (${...} DISINDA) kalmis -> sekme cubuguna duz metin "/* FINANS_GATE_V1 */" render oluyordu.
#   Yorumu KALDIR. Gate mantigi (allowedDepts.includes("finansodasi")) AYNEN kalir.
#   Satir 651 DOGRU (gercek JS yorumu, template disi) -> DOKUNULMAZ.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/bi.js"
s = open(F, encoding="utf-8").read()
OLD = ": ''}  /* FINANS_GATE_V1 */"
NEW = ": ''}"
if OLD not in s:
    print("[skip] zaten duzeltilmis (sizan yorum yok)"); sys.exit(0)
assert s.count(OLD) == 1, "anchor sayisi beklenmedik (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] FINANS_GATE_FIX_V1 (nav sizan yorum kaldirildi)")
