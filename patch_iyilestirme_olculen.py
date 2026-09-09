#!/usr/bin/env python3
# TAHSILAT_IYILESTIRME_V1 — iyilestirme-hedefleri "tahsilat" ve "gecikme" bayraklarini OLCULEN sinyale cevirir.
#   tahsilat: DSO > KRB ort DSO*1.15 ; gecikme: %gec>55 veya ort gun>15 (bi_tahsilat, son12/tam).
#   Kolonlar TAHSILAT_KIYAS_V1 ile zaten sorguda. Tahsilat kaydi yoksa ESKI mantik (fallback).
#   Yalnizca iyilestirme-hedefleri JS. Literal + tam sayim (assert). Idempotent.
import sys

FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
s = open(FP, encoding="utf-8").read()

if "TAHSILAT_IYILESTIRME_V1" in s:
    print("zaten yamali (TAHSILAT_IYILESTIRME_V1), atlandi"); print("DONE."); raise SystemExit

def rep(old, new, need, tag):
    global s
    c = s.count(old)
    assert c == need, "SAYIM YANLIS: " + tag + " beklenen=" + str(need) + " bulunan=" + str(c)
    s = s.replace(old, new)
    print(f"  {tag}: {need} degisiklik")

# 1) iyilestirme .map destructuring -> olculen degiskenler
rep("          const odPct = n(x.od_pct), krbOd = n(x.krb_od_pct), buyume = n(x.buyume), overdue = n(x.overdue);\n",
    "          const odPct = n(x.od_pct), krbOd = n(x.krb_od_pct), buyume = n(x.buyume), overdue = n(x.overdue);\n"
    "          const dso = n(x.dso), krbDso = n(x.krb_dso), gecp = n(x.gecp), gecikmeGun = n(x.gecikme_gun), hasTah = x.has_tah === true; /* TAHSILAT_IYILESTIRME_V1 */\n",
    1, "iy_vars")

# 2) tahsilat bayragi -> olculen DSO (fallback eski vade)
rep('          if (vade != null && krbVade != null && vade > krbVade * 1.15) bayrak.push("tahsilat");\n',
    '          if (hasTah && dso != null && krbDso != null ? dso > krbDso * 1.15 : (vade != null && krbVade != null && vade > krbVade * 1.15)) bayrak.push("tahsilat"); /* TAHSILAT_IYILESTIRME_V1 */\n',
    1, "iy_tahsilat_flag")

# 3) gecikme bayragi -> olculen %gec/gun (fallback eski overdue)
rep('          if (overdue != null && n(x.ciro) > 0 && overdue > n(x.ciro) * 0.10 && overdue > 50000) bayrak.push("gecikme"); /* SMARTKIYAS_V2 */\n',
    '          if (hasTah && gecp != null ? (gecp > 55 || (gecikmeGun != null && gecikmeGun > 15)) : (overdue != null && n(x.ciro) > 0 && overdue > n(x.ciro) * 0.10 && overdue > 50000)) bayrak.push("gecikme"); /* TAHSILAT_IYILESTIRME_V1 */\n',
    1, "iy_gecikme_flag")

open(FP, "w", encoding="utf-8").write(s)
print("yamalandi: TAHSILAT_IYILESTIRME_V1 (iyilestirme bayraklari olculene bagli)")
print("DONE.")
