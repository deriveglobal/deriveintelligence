#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "###### 1) ONERI / GERI BILDIRIM TABLOLARI ######"
$PSQL -c "SELECT relname AS tablo, n_live_tup AS satir FROM pg_stat_user_tables
 WHERE relname ~ 'oneri|geri_bildirim|feedback|talep|istek|sikayet|bildirim|ticket|destek'
 ORDER BY n_live_tup DESC;"

echo; echo "###### 2) ICERIK — temsilciler NE YAZMIS? ######"
for T in $($PSQL -tAc "SELECT relname FROM pg_stat_user_tables
   WHERE relname ~ 'oneri|geri_bildirim|feedback|sikayet|ticket' AND n_live_tup > 0
   ORDER BY n_live_tup DESC"); do
  echo; echo "  ====== $T ======"
  $PSQL -c "SELECT column_name, data_type FROM information_schema.columns
            WHERE table_name='$T' ORDER BY ordinal_position;"
  $PSQL -x -c "SELECT * FROM $T ORDER BY 1 DESC LIMIT 20;"
done

echo; echo "###### 3) SAHA TABLOLARI ######"
$PSQL -c "SELECT relname, n_live_tup FROM pg_stat_user_tables
 WHERE relname LIKE 'saha_%' AND n_live_tup > 0 ORDER BY n_live_tup DESC LIMIT 15;"

echo; echo "###### 4) CEVAP VERILMIS MI? ######"
cd /opt/krb-assessment
grep -n "oneri" server_container.mjs | grep -i "api/saha\|method ===" | head -8
