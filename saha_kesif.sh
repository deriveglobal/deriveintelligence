#!/usr/bin/env bash
# SAHA_KESIF — YAMADAN ONCE. Hicbir sey degistirmez, sadece OKUR.
#
# ⚠ Bunu yaziyorum cunku ops_monitor.py'de 4 kez ust uste yanlis capa kullandim:
#   ekrandan okudugum girintiyi elle yazdim, tutmadi. Bir daha olmayacak.
#   Her capa DOSYADAN cikacak, benim hafizamdan degil.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ A) SEMA — tablolar gercekten BOS mu? ############"
$PSQL -c "
SELECT 'destek' AS tablo, count(*) FROM saha_musteri_tedarikci_destek
UNION ALL SELECT 'destek_log', count(*) FROM saha_musteri_tedarikci_destek_log;
"
$PSQL -c "
SELECT table_name, column_name, data_type, is_nullable
  FROM information_schema.columns
 WHERE table_name IN ('saha_musteri_tedarikci_destek','saha_musteri_tedarikci_destek_log','saha_musteri','saha_ziyaret')
   AND column_name IN ('id','musteri_id','destek_id','rep_id','sorumlu_rep','tenant_id')
 ORDER BY table_name, column_name;
"
echo "-- users tablosunda isim sutunu hangisi? (name mi full_name mi?) --"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position;"

echo
echo "############ B) KOD — capalar DOSYADAN ############"
echo "-- 1) UUID regex sabiti var mi, adi ne? --"
grep -n "UUID_RE\|uuidRe\|UUID_PATTERN\|\[0-9a-f\]{8}" server_container.mjs | head -8

echo
echo "-- 2) musteri-destek rotalari (500'un ve \\d+ tuzaginin yeri) --"
grep -n "api/saha/musteri-destek" server_container.mjs

echo
echo "-- 3) ziyaretler rotalari (GET tek ziyaret GERCEKTEN yok mu?) --"
grep -n "api/saha/ziyaretler" server_container.mjs

echo
echo "-- 4) 403 'size atanmamış' — kac yerde, hangi metodlarda? --"
grep -n "size atanmamış" server_container.mjs

echo
echo "-- 5) GET musteri detayinin YANIT satiri (capa icin birebir lazim) --"
grep -n "musteri: result.rows\[0\]\|musteri: r.rows\[0\]\|{ musteri:" server_container.mjs | head -6

echo
echo "############ C) ⚠ Eftal bugun ne gordu? ############"
$PSQL -c "
SELECT to_char(created_at,'HH24:MI') saat, http_status kod, endpoint,
       left(coalesce(hata_mesaji,''),58) hata
  FROM saha_hata_log
 WHERE user_id='ae0c55f9-68cc-421d-96d9-409222452f1a'
   AND created_at::date >= current_date - 1
 ORDER BY created_at;
"
echo
echo "⚠ BU CIKTIYI BANA YAPISTIR. Yamayi capalari GORDUKTEN sonra yazacagim."
