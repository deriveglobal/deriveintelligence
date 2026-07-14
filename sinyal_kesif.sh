#!/usr/bin/env bash
# SINYAL_KESIF — ekran dogru, ama ALARMI ureten motor ne diyor?
#
# ⚠ Ekrani duzeltip alarmi duzeltmemek, hicbir sey duzeltmemektir.
#   Sistem yine MUTAFLAR'a bagirir (net 1,0M — sorun DEGIL),
#   TOROS sessiz kalir (limitin 47 kati — GERCEK sorun).
#
# ⚠ Ayrica: kredi_limiti'nde 0 yerine 1 TL gibi degerler var.
#   FARK GROUP "6.400.296 kat asim" gorunuyor. Bu YANLIS ALARM uretir.
#   "Limit tanimlanmamis" ile "limit asilmis" AYNI SEY DEGIL.
#
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) sinyal_kredi — motorun TAM SQL'i ############"
awk '/^  "sinyal_kredi": """/,/^  """/ { printf "%5d| %s\n", NR, $0 }' erp_ingest.py

echo
echo "############ 2) bi_sinyal — su an ekranda hangi alarmlar var? ############"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_sinyal' ORDER BY ordinal_position;"
$PSQL -c "SELECT * FROM bi_sinyal ORDER BY 1 LIMIT 5;" 2>/dev/null | head -20

echo
echo "############ 3) ⚠ KREDI ALARMLARI — kime bagiriyor? ############"
$PSQL -c "SELECT * FROM bi_sinyal WHERE tur ILIKE '%kredi%' OR baslik ILIKE '%limit%' OR baslik ILIKE '%risk%' LIMIT 10;" 2>/dev/null \
  || $PSQL -x -c "SELECT * FROM bi_sinyal LIMIT 3;"

echo
echo "############ 4) ⚠ LIMIT VERISI — 0 mi, 1 mi, NULL mu? ############"
$PSQL -c "
SELECT count(*)                                      AS musteri,
       count(*) FILTER (WHERE kredi_limiti IS NULL)  AS limit_NULL,
       count(*) FILTER (WHERE kredi_limiti = 0)      AS limit_sifir,
       count(*) FILTER (WHERE kredi_limiti > 0 AND kredi_limiti < 1000) AS limit_1_ile_1000_arasi,
       count(*) FILTER (WHERE kredi_limiti >= 1000)  AS limit_gercek
  FROM master_musteri WHERE son_bakiye IS NOT NULL;"
echo "  --- 'limiti 1000 TL'den kucuk ama bakiyesi milyonlarca' olanlar ---"
$PSQL -c "
SELECT left(musteri_adi,32) musteri, round(net_pozisyon/1e3) net_bin, kredi_limiti
  FROM master_musteri
 WHERE net_pozisyon > 1e6 AND kredi_limiti > 0 AND kredi_limiti < 1000
 ORDER BY net_pozisyon DESC LIMIT 6;"
echo "  ⚠ Bunlar 'limit asildi' DEGIL, 'limit TANIMLANMAMIS'. Ikisi ayri sey."

echo
echo "############ 5) bi_sinyal'i KIM okuyor? (ekranda nerede cikiyor) ############"
grep -n "bi_sinyal" server_container.mjs | head -8
