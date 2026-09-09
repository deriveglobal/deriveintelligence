#!/usr/bin/env bash
# IL_ILCE_8_TEKLISTE — iki il listesi var. Biri olmeli.
#
# ⚠ ONCE: 7. adimin "❌ HAYIR" cevabi YANLISTI. Kapim kendini yendi:
#     set -o pipefail  +  curl | head -20 | grep -q
#   grep -q ilk eslesmede cikar -> head SIGPIPE alir -> 141 -> pipefail boruyu
#   basarisiz sayar -> if "HAYIR" der. YANI ESLESME BULDUGU ICIN BASARISIZ OLDU.
#   Bu betikte pipefail YOK ve grep -q YERINE sayim var.
#
# ⚠ SORUN: saha.js:5860 eski TR_ILLER dizisi · 6331 kullaniyor.
#   Yeni form TR_ILLER_RESMI kullaniyor (787, 859).
#   Iki liste bir listeden kotudur: hangisinin ekranda oldugunu kimse bilemez.
#
# ⚠ OKUMADAN OLDURMEM. Once 6331 NE oldugunu gorecegim.
set -u   # ⚠ pipefail YOK — kapiyi yine kendim kirmayayim
cd /opt/krb-assessment || exit 1
SJ=shells/saha.js

echo "############ 1) ⚠ ONCE 7. ADIMIN YALANI — import GERCEKTEN orada mi? ############"
N=$(curl -s http://localhost:8080/shells/saha.js | grep -c 'tr_il_ilce\.js')
echo "  servis edilen saha.js icinde 'tr_il_ilce.js' gecen satir: $N"
if [ "$N" -ge 1 ]; then
  echo "  ✅ IMPORT ORADA. 7. adimin '❌ HAYIR'i kapinin kendi hatasiydi."
else
  echo "  ❌ GERCEKTEN YOK — dur, deploy tutmamis."
  exit 1
fi

echo
echo "############ 2) ESKI LISTE — 5860 ve 6331 NE? ############"
echo "  --- 5855-5866 (dizinin basi) ---"
sed -n '5855,5866p' "$SJ" | nl -ba -v5855 | sed 's/^/  /'
echo
echo "  --- ⚠ 6320-6345 (KULLANILDIGI YER — asil soru bu) ---"
sed -n '6320,6345p' "$SJ" | nl -ba -v6320 | sed 's/^/  /'

echo
echo "############ 3) ⚠ 6331 HANGI FONKSIYONUN ICINDE? ############"
awk 'NR<=6331 && (/^(async )?function /||/^const [A-Za-z_$]+ = (async )?\(/||/^  (async )?function /)' "$SJ" \
  | tail -3 | sed 's/^/  /'
echo "  --- 6331 civarindaki element id'leri (hangi ekran?) ---"
sed -n '6300,6360p' "$SJ" | grep -o 'id="[a-z0-9-]*"' | sort -u | sed 's/^/  /'

echo
echo "############ 4) ⚠ DIZI GERCEKTEN 81 IL MI? — eski liste ne kadar guvenilir ############"
python3 - <<'PY'
import io, re, ast
s = io.open("shells/saha.js", encoding="utf-8").read()
m = re.search(r'const TR_ILLER = (\[.*?\]);', s, re.S)
if not m:
    print("  ❌ dizi ayristirilamadi"); raise SystemExit
try:
    liste = ast.literal_eval(m.group(1))
except Exception as e:
    print("  ⚠ ayristirilamadi:", e); raise SystemExit
print(f"  eski TR_ILLER: {len(liste)} il")
resmi = re.search(r'window\.TR_ILLER_RESMI = (\[.*?\]);', io.open("shells/tr_il_ilce.js", encoding="utf-8").read(), re.S)
r = ast.literal_eval(resmi.group(1))
print(f"  resmi liste  : {len(r)} il")
eksik = [x for x in r if x not in liste]
fazla = [x for x in liste if x not in r]
print(f"  ⚠ eski listede OLMAYAN resmi il : {len(eksik)}  {eksik[:8]}")
print(f"  ⚠ eski listede FAZLADAN olan    : {len(fazla)}  {fazla[:8]}")
print("  ⚠ Fark varsa: eski liste EKSIK/YANLIS. Resmi liste kazanir.")
PY

echo
echo "############ SONUC — KARAR BENDE DEGIL, VERIDE ############"
echo "  ⚠ 3) 6331 hangi ekransa, ORASI da resmi listeye gecmeli."
echo "  ⚠ Simdi DOKUNMADIM. Ne oldugunu gordukten sonra tek hamlede oldururum."
