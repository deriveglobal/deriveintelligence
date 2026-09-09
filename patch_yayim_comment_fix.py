# -*- coding: utf-8 -*-
# YAYIM_COMMENT_FIX_V1 (mobil) — YAYIM_OKUNDU yamasinda template literal ICINE dusen
#   "/* YAYIM_OKUNDU_V1 */" yorumu ekranda METIN olarak gorunuyordu. Yorumu kaldir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()

OLD = '</div>`).join("")}  /* YAYIM_OKUNDU_V1 */'
NEW = '</div>`).join("")}'
if OLD not in s:
    print("[skip] sizinti yok, zaten temiz"); sys.exit(0)
assert s.count(OLD) == 1, "anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_COMMENT_FIX_V1")
