# -*- coding: utf-8 -*-
# YAYIM_OKUNDU_V1 (masaustu) — yayim satirinda 👁 X/Y okuyan gostergesi.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "YAYIM_OKUNDU_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# D1) destructure -> rep_toplam
OLD1 = "  const { konusmalar = [], yayimlar = [] } = data;"
NEW1 = "  const { konusmalar = [], yayimlar = [], rep_toplam = 0 } = data;  /* YAYIM_OKUNDU_V1 */"
assert s.count(OLD1) == 1, "destructure anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# D2) yayim render -> okuyan
OLD2 = '${yayimlar.map(y => `<div class="sub2" style="padding:3px 0">${esc(y.icerik.slice(0, 90))}${y.icerik.length > 90 ? "…" : ""} · ${_dkKisaTs(y.created_at)}</div>`).join("")}'
NEW2 = '${yayimlar.map(y => `<div class="sub2" style="padding:3px 0">${esc(y.icerik.slice(0, 90))}${y.icerik.length > 90 ? "…" : ""} · ${_dkKisaTs(y.created_at)}${y.okuyan!=null?` · 👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""}`:""}</div>`).join("")}'
assert s.count(OLD2) == 1, "yayim-render anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_OKUNDU_V1 (masaustu)")
