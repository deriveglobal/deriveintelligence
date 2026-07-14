#!/usr/bin/env bash
# SON_IKI_IS — (1) marji GERCEKTEN olc  (2) 'kat' hatasini Bugun'de de kapat.
#
# ✅ IKI EKRAN HIZALANDI:
#   stok 268,5M · alacak 209,3M · borc 403,4M · net 74,4M · yuk 29,7M · DSO 102 gun
#   DSO 116'dan 102'ye dustu: artik bekleyen siparisi alacak SANMIYOR.
#
# ⚠ IS 1 — bi_marj_fact.tenant_id TEXT'mis, ben UUID cast'ledim ve PATLADI.
#   Bu, SABAH dustugum tuzagin AYNISI (14 tabloda TEXT, 30 tabloda UUID).
#   Marjin gercek degerini HALA olcemedim. Ekran %7,9 diyor, koken %8,3 yaziyor.
#
# ⚠ IS 2 — bi.js:441. Bugun ekranindaki risk listesi limiti 1 TL olan musteriyi
#   BOLUYOR ve "3.523.352 kat" yaziyor. Finans'ta duzelttim, Bugun'de duruyor.
#   Ayni hata iki yerde FARKLI davraniyor — ayni hesabi iki yerde yazmanin BEDELI.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ MARJ — dogru cast ile (tenant_id TEXT) ############"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_marj_fact' AND column_name='tenant_id';"
$PSQL -c "
SELECT round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0), 1)  AS marj_pct,
       round(sum(ciro)/1e6, 1)      AS ciro_M,
       round(sum(brut_kar)/1e6, 1)  AS brut_kar_M,
       count(*)                     AS satir
  FROM bi_marj_fact
 WHERE tenant_id='$T' AND ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok';"
echo "  ⚠ EKRAN %7,9 diyor. KUP ne diyor? Kupte ne varsa O DOGRU."

echo
echo "  --- prim dahil efektif marj ---"
$PSQL -c "
WITH m AS (
  SELECT sum(ciro) c, sum(brut_kar) k FROM bi_marj_fact
   WHERE tenant_id='$T' AND ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok'),
p AS (SELECT COALESCE(sum(tutar),0) prim FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid)
SELECT round(100.0*m.k/NULLIF(m.c,0),1) AS marj_prim_haric,
       round(100.0*(m.k+p.prim)/NULLIF(m.c,0),1) AS marj_prim_dahil,
       round(p.prim/1e6,1) AS prim_M
  FROM m, p;" 2>&1 | head -6

echo
echo "############ 2) bi.js:441 — 'kat' satirini GOR, sonra yamala ############"
awk 'NR>=430 && NR<=452 { printf "%4d| %s\n", NR, $0 }' shells/bi.js

echo
echo "############ 3) YAMA — limit YOKSA 'kat' YOK ############"
cp shells/bi.js shells/bi.js.bak_kat
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "KAT_FIX_V1" in s: sys.exit("ZATEN YAMALI")
lines = s.split("\n")
hedef = None
for i, l in enumerate(lines):
    if "kat" in l and ("limit" in l or "kredi" in l or "_kat" in l):
        hedef = i
        break
if hedef is None:
    sys.exit("❌ 'kat' satiri bulunamadi — elle bakilacak")
print(f"  hedef satir {hedef+1}:")
print("   ", lines[hedef].strip()[:160])
# ⚠ Korlemesine degistirmiyorum: sadece RAPOR ediyorum.
#   Satiri gordukten sonra hedefli yama yazilacak.
sys.exit(0)
PY

echo
echo "  ⚠ Satiri yukarida bastim. Korlemesine degistirmiyorum —"
echo "     gordukten sonra hedefli yamayi yazacagim."
