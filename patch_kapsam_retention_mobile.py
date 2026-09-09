# -*- coding: utf-8 -*-
# KAPSAM_RETENTION_V1 (mobil) — Kapsam kart meta satirina tekrar-alim rozeti.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_RETENTION_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) CSS — .kp-row'dan sonra
o1 = ".kp-row{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:11px 13px;margin-bottom:8px}"
n1 = o1 + ".kp-tk{font-weight:700}.kp-tk.kayiyor{color:#C43D28}.kp-tk.sadik{color:#106B4A}  /* KAPSAM_RETENTION_V1 */"
assert s.count(o1) == 1, "css anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rozet — card kp-meta (son ziyaret'ten sonra; segEt(x.tip) card'a ozgu -> esizCard'i etkilemez)
o2 = r'''segEt(x.tip) : ""} · son ${sonTxt(x.gun)}${yon && x.rep'''
n2 = r'''segEt(x.tip) : ""} · son ${sonTxt(x.gun)}${x.tk && x.tk.durum && x.tk.durum !== "sessiz" ? ` · <b class="kp-tk ${x.tk.durum}">${x.tk.durum === "kayiyor" ? "🔴 kayıyor" : "🟢 sadık"}</b>` : ""}${yon && x.rep'''
assert s.count(o2) == 1, "rozet anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_RETENTION_V1 (mobil) — rozet")
