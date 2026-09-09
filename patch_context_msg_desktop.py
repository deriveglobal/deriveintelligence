# -*- coding: utf-8 -*-
# CONTEXT_MSG_DK_V1 (masaustu) — thread baloncugunda baglam 🔗 rozeti (musteri kart girisi sonraki dilim).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "CONTEXT_MSG_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '<div class="dk-msg ${benim ? "me" : x._y ? "yayim" : "ai"}">${esc(x.icerik)}</div>'
NEW = '<div class="dk-msg ${benim ? "me" : x._y ? "yayim" : "ai"}"><!--CONTEXT_MSG_DK_V1-->${x.baglam_etiket ? `<div style="font-size:10px;opacity:.8;margin-bottom:3px">🔗 ${esc(x.baglam_etiket)}</div>` : ""}${esc(x.icerik)}</div>'
assert s.count(OLD) == 1, "bubble anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CONTEXT_MSG_DK_V1 (masaustu)")
