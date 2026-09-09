#!/usr/bin/env bash
# IL_ILCE_11_SEHIR_TABLO — sehirler AYRI TABLODA. Hangisi, ne yaziyor?
# SADECE OKUR.
#
# ⚠ 31222: PUT /api/saha/admin/reps/:id/sehirler bir tabloya INSERT ediyor.
#   31204: GET /api/saha/reps o tablodan array olarak okuyor.
#   Once 31222-31235'i OKUYUP tablo adini alacagim, sonra icini okuyacagim.
set -u
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ PUT sehirler ENDPOINT'i — HANGI TABLO? ############"
sed -n '31222,31240p' server_container.mjs | nl -ba -v31222 | sed 's/^/  /'

echo
echo "############ 2) ⚠ GET reps — sehirler'i NASIL okuyor? ############"
sed -n '31195,31215p' server_container.mjs | nl -ba -v31195 | sed 's/^/  /'

echo
echo "############ 3) sehir gecen TUM tablolar (isim bazli) ############"
$PSQL -c "
SELECT table_name FROM information_schema.tables
 WHERE table_schema='public'
   AND (table_name ILIKE '%sehir%' OR table_name ILIKE '%rep%bolge%' OR table_name ILIKE '%bolge%')
 ORDER BY 1;"

echo
echo "############ 4) ⚠ saha_rep* tablolari — hangileri var? ############"
$PSQL -c "
SELECT table_name FROM information_schema.tables
 WHERE table_schema='public' AND table_name ILIKE 'saha_rep%'
 ORDER BY 1;"
