# -*- coding: utf-8 -*-
# PTR_DAHA_FIX_V1 — Mobil saha: Mesajlar (veya baska "Daha" alti gorunum) acikken
#   yukari cek-birak (pull-to-refresh) yapinca refresh() aktif nav sekmesine tikliyordu;
#   aktif sekme "Daha" oldugu icin tiklama Daha sayfasini (sheet) ACIYORDU, yenilemiyordu.
#   Cozum: aktif sekme "daha" ise sekmeye tiklama; mevcut gorunumu loadView(S.view) ile yenile.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "PTR_DAHA_FIX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '      if (nv && getComputedStyle(nv).display !== "none") { var t = nv.querySelector(".saha-tab.on"); if (t) { t.click(); return; } }'
NEW = '      if (nv && getComputedStyle(nv).display !== "none") { var t = nv.querySelector(".saha-tab.on"); if (t) { if (t.dataset.v === "daha") { try { if (typeof loadView === "function" && S && S.view) { loadView(S.view); return; } } catch (e) {} } t.click(); return; } }  /* PTR_DAHA_FIX_V1 */'
assert s.count(OLD) == 1, "anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] PTR_DAHA_FIX_V1")
