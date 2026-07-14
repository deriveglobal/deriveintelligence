#!/usr/bin/env bash
# DUYURU_KESIF — duyuru tablosunu VARSAYMADAN once semasini okuyorum.
# ⚠ Bugun bes kez kolon adini hafizamdan yazip yanildim. Alti olmayacak.
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) Duyuru tablolari ############"
$PSQL -c "SELECT table_name FROM information_schema.tables
          WHERE table_name ILIKE '%duyuru%' OR table_name ILIKE '%announce%';"

echo
echo "############ 2) Sutunlar ############"
for T in $($PSQL -tAc "SELECT table_name FROM information_schema.tables WHERE table_name ILIKE '%duyuru%'"); do
  echo "  --- $T ---"
  $PSQL -c "SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns WHERE table_name='$T' ORDER BY ordinal_position;"
  echo "  --- CHECK kisitlari ($T) ---"
  $PSQL -c "SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
            WHERE conrelid='$T'::regclass AND contype='c';"
done

echo
echo "############ 3) Mevcut duyurular — ornek satir (bicimi gormek icin) ############"
T=$($PSQL -tAc "SELECT table_name FROM information_schema.tables WHERE table_name ILIKE '%duyuru%' ORDER BY table_name LIMIT 1")
$PSQL -x -c "SELECT * FROM $T ORDER BY 1 DESC LIMIT 2;"

echo
echo "############ 4) Uc nokta — arayuz nasil yaziyor? ############"
grep -n "duyuru" server_container.mjs | grep -i "api/saha\|method ===" | head -10
echo "  --- arayuz tarafi ---"
grep -n "duyuru" shells/saha.js | head -10
