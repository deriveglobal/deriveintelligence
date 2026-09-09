#!/usr/bin/env python3
# MARKATIER_UI_V1 — Marj Alarmi UI: sabit "Hedef marj %12" yerine "markaya ozel" + her satirda
# markaya-ozel hedef (marj hucresinde "/h%X"). kokpit.html. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/kokpit.html"
s = read(FP)
if "MARKATIER_UI_V1" in s:
    print("markatier-ui: already present, skip"); print("DONE."); raise SystemExit
assert "MARJALARM_UI_V1" in s, "once MARJALARM_UI_V1 uygulanmali"

# (1) Baslik: "Hedef marj %X" -> "markaya ozel"
A_h = '<div><div class="l">Hedef marj</div><div class="v">%${M(d.hedef*100)}</div></div>'
assert s.count(A_h) == 1, "hedef baslik anchor"
N_h = '<div><div class="l">Hedef marj</div><div class="v" style="font-size:15px">markaya özel<span style="font-size:10px;color:var(--mut)"> /* MARKATIER_UI_V1 */</span></div></div>'
s = s.replace(A_h, N_h, 1)

# (2) Ana satir marj hucresine markaya-ozel hedef
A_m = ('<td style="color:${mcol(x.marj_pct)}">%${M(x.marj_pct)}</td>\n'
       '    <td>${M(x.avg_satis)}</td>\n'
       "    <td>${x.repl_cost!=null?M(x.repl_cost):'—'}</td>")
assert s.count(A_m) == 1, "ana satir marj hucresi anchor"
N_m = ('<td style="color:${mcol(x.marj_pct)}">%${M(x.marj_pct)}<span style="color:var(--mut)"> /h%${M(x.hedef_pct)}</span></td>\n'
       '    <td>${M(x.avg_satis)}</td>\n'
       "    <td>${x.repl_cost!=null?M(x.repl_cost):'—'}</td>")
s = s.replace(A_m, N_m, 1)

write(FP, s)
print("markatier-ui: baslik + satir hedef gosterimi")
print("marker count:", s.count("MARKATIER_UI_V1"))
print("DONE.")
