#!/usr/bin/env bash
# DENETIM_115_DSO — uc DSO kaynagini CANLI olc + evren duzeltmesi. SADECE OKUR.
#   Karar Fatih'in; ben sayilari kanitla sunuyorum.
set -uo pipefail
cd /opt/krb-assessment || exit 1
SRC="server_container.mjs"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. UC KAYNAGIN KOD FORMULLERI"
echo "--- (A) EKRAN: alacak ÷ gunluk ciro (23920-23935) ---"
sed -n '23920,23940p' "$SRC" | nl -ba -v23920 | sed 's/^/  /'
echo "--- (B) bi_fatura_tahsilat (24188-24205) ---"
sed -n '24188,24205p' "$SRC" | nl -ba -v24188 | sed 's/^/  /'
echo "--- (C) bi_odeme_gecmisi (27760-27775) ---"
sed -n '27760,27775p' "$SRC" | nl -ba -v27760 | sed 's/^/  /'

hr "2. ⚠ CANLI OLCUM — dort DSO yan yana"
$PSQL -c "
WITH
alacak AS (SELECT sum(hesap_bakiyesi) AS a FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi),
lastik AS (SELECT sum(satir_tutar) AS c FROM bi_satis_faturalari WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365 AND ebat IS NOT NULL),
tum    AS (SELECT sum(satir_tutar) AS c FROM bi_satis_faturalari WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365)
SELECT
  round((SELECT a FROM alacak)/1e6,1)                                   AS alacak_m,
  round((SELECT a FROM alacak) / ((SELECT c FROM lastik)/365))          AS dso_ekran_lastik,
  round((SELECT a FROM alacak) / ((SELECT c FROM tum)/365))             AS dso_evren_duzeltilmis,
  round((SELECT c FROM lastik)/1e6)                                     AS lastik_ciro_m,
  round((SELECT c FROM tum)/1e6)                                        AS tum_ciro_m;"
echo "  ⚠ dso_ekran_lastik (~102): pay=tum alacak, payda=SADECE lastik -> sisik"
echo "  ⚠ dso_evren_duzeltilmis (~81): pay ve payda ayni evren (tum sirket)"

echo
echo "--- (B) bi_fatura_tahsilat ne veriyor? ---"
$PSQL -c "SELECT round(avg(tahsilat_gun),1) AS ort_tahsilat_gun, count(*) AS fatura
          FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid AND tahsilat_gun IS NOT NULL;" 2>&1 | sed 's/^/  /'
echo "--- (C) bi_odeme_gecmisi ne veriyor? (26.9 kaynagi — sadece ODENEN faturalar) ---"
$PSQL -c "SELECT count(*) satir, count(DISTINCT tahsilat_turu) tur FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "3. ⚠ NEDEN 26.9 YALAN — odenmemis 145M o ortalamada YOK"
$PSQL -c "
SELECT round(sum(hesap_bakiyesi)/1e6,1) AS alacak_m,
       round(sum(vadesi_gecmis)/1e6,1)  AS vadesi_gecmis_m,
       round(100.0*sum(vadesi_gecmis)/nullif(sum(hesap_bakiyesi),0),0) AS gecikmis_pct
  FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi;"
echo "  ⚠ bi_odeme_gecmisi SADECE odenenleri olcer -> hayatta kalan yanliligi."
echo "     145M odemeyen o ortalamada yok. 26.9 gun 'ne kadar hizli tahsil ediyoruz' DEGIL,"
echo "     'odeyenler ne kadar hizli odedi'. DSO diye gostermek yaniltir."

hr "4. Her uc kaynak ekranda/promptta NEREDE kullaniliyor?"
grep -nE "bi_odeme_gecmisi|bi_fatura_tahsilat" "$SRC" | sed 's/^/  /'

hr "BITTI — karar: hangisi 'DSO', otekiler ne olsun (sil / ayri etiketli olcum)"
