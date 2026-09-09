#!/usr/bin/env python3
# DONGU_KANON_ANA_V1 — Faz B: /api/bi/ana "Bugun" odasi dso_gun + stok_gun -> v_finans_ticari_sermaye (bilanco-tabanli kanon).
# Eski ciro-bazli proxy (risk/gunluk-ciro, s.deger/gunluk-ciro) kaldirildi. Boylece Bugun odasi dongu sayilari
# Finans odasi ile BIREBIR (DSO 100 / DIO 146). Olculen tahsilat hizi (bi_metrik_gecmis 'dso', ~27) AYRI lens, dokunulmadi.
# Param baglami: sorgu [T, T] ile cagriliyor; $2::uuid zaten bu sorguda kullaniliyor (bi_ayar/bi_tedarikci). text=uuid tuzagi YOK.
# Idempotent, count==1 guard.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
changes = []
def apply(name, new, old):
    global src
    if new in src:
        changes.append(f"SKIP (zaten var): {name}"); return
    c = src.count(old)
    assert c == 1, f"ANCHOR COUNT != 1 ({c}) : {name}"
    src = src.replace(old, new)
    changes.append(f"OK: {name}")

# 1) stok_gun -> canon DIO
apply(
  "ANA stok_gun -> v_finans DIO",
  "                 (SELECT round(dio) FROM v_finans_ticari_sermaye WHERE tenant_id=$2::uuid)  AS stok_gun,  /* DONGU_KANON_ANA_V1 */",
  "                 ROUND(s.deger  / NULLIF(c.gunluk,0))                AS stok_gun,",
)

# 2) dso_gun -> canon DSO (+ yorumu guncelle)
apply(
  "ANA dso_gun -> v_finans DSO",
  "                 -- DONGU_KANON_ANA_V1: dso_gun/stok_gun -> v_finans_ticari_sermaye (bilanco-tabanli kanon; DSO 100 / DIO 146). Eski risk/gunluk-ciro proxy kaldirildi. Olculen tahsilat hizi AYRI lens (bi_metrik_gecmis 'dso').\n"
  "                 (SELECT round(dso) FROM v_finans_ticari_sermaye WHERE tenant_id=$2::uuid)  AS dso_gun,",
  "                 -- ⚠ GERCEK DSO: tahsil EDILMEYENI de icerir. Tablo 26,9 diyordu; yalan.\n"
  "                 ROUND(a.risk   / NULLIF(c.gunluk,0))                AS dso_gun,",
)

if src == orig:
    print("DEGISIKLIK YOK")
else:
    bak = PATH + ".bak_donguana_" + time.strftime("%Y%m%d_%H%M%S")
    shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(src)
for c in changes: print(" ", c)
print("DONGU_KANON_ANA_V1 marker:", src.count("DONGU_KANON_ANA_V1"))
