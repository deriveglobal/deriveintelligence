# -*- coding: utf-8 -*-
# KAPSAM_RETENTION_V1 (masaustu) — Kapsam musteri listesi satirlarina tekrar-alim rozeti.
#   🔴 kayiyor (onceki 6 ay aldi, son 6 ay yok) / 🟢 sadik (son 6 ay aldi). Server x.tk'den.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_RETENTION_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) CSS
o1 = ".kap-firma{font-weight:600}"
n1 = ".kap-firma{font-weight:600}.kap-tk{font-weight:700;font-size:9.5px;white-space:nowrap}.kap-tk.kayiyor{color:#C43D28}.kap-tk.sadik{color:#106B4A}/* KAPSAM_RETENTION_V1 */"
assert s.count(o1) == 1, "css anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rozet — listRows kap-sub (segEt(x.tip)'ten sonra, durum'dan once)
o2 = r'''${x.tip ? " · " + segEt(x.tip) : ""}${(S._kapAll && x.durum)'''
n2 = r'''${x.tip ? " · " + segEt(x.tip) : ""}${x.tk && x.tk.durum && x.tk.durum !== "sessiz" ? ` · <span class="kap-tk ${x.tk.durum}" title="son 12 ay ${x.tk.vc} ziyaret">${x.tk.durum === "kayiyor" ? "🔴 kayıyor" : "🟢 sadık"}</span>` : ""}${(S._kapAll && x.durum)'''
assert s.count(o2) == 1, "rozet anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_RETENTION_V1 (masaustu) — rozet")
