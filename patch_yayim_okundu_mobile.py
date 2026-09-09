# -*- coding: utf-8 -*-
# YAYIM_OKUNDU_V1 (mobil) — yayim satirinda 👁 X/Y okuyan gostergesi.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "YAYIM_OKUNDU_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# M1) destructure -> rep_toplam
OLD1 = "      const { konusmalar, yayimlar } = data;"
NEW1 = "      const { konusmalar, yayimlar, rep_toplam = 0 } = data;  /* YAYIM_OKUNDU_V1 */"
assert s.count(OLD1) == 1, "destructure anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# M2) yayim render -> okuyan
OLD2 = '          ${yayimlar.map(y => `<div style="font-size:12px;color:#713f12;padding:4px 0;border-bottom:1px solid #fef08a">${esc(y.icerik.slice(0,80))}${y.icerik.length>80?"…":""} <span style="color:#a16207">${_msgKisaTs(y.created_at)}</span></div>`).join("")}'
NEW2 = '          ${yayimlar.map(y => `<div style="font-size:12px;color:#713f12;padding:4px 0;border-bottom:1px solid #fef08a">${esc(y.icerik.slice(0,80))}${y.icerik.length>80?"…":""} <span style="color:#a16207">${_msgKisaTs(y.created_at)}</span>${y.okuyan!=null?` · <span style="color:#a16207">👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""}</span>`:""}</div>`).join("")}  /* YAYIM_OKUNDU_V1 */'
assert s.count(OLD2) == 1, "yayim-render anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_OKUNDU_V1 (mobil)")
