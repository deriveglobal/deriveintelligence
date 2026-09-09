#!/usr/bin/env bash
# IL_ILCE_10_SEHIR_KESIF — SADECE OKUR.
#
# ⚠ 9. adim durdu: users tablosunda 'sehirler' KOLONU YOK.
#   Ama arayuz rep.sehirler OKUYOR (saha.js:6330) ve kaydediyor.
#   Peki atanan sehir NEREYE gidiyor? Uc olasilik:
#     1) baska kolon (jsonb icinde: metadata / profile / settings)
#     2) baska tablo (user_sehir / rep_bolge ...)
#     3) HICBIR YERE — arayuz kaydediyor ama sunucu atiyor (sessiz kayip)
#
# ⚠ TAHMIN ETMIYORUM. server_container.mjs'te temsilci kaydini OKUYACAGIM.
set -u
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) users TABLOSUNUN TUM KOLONLARI ############"
$PSQL -c "
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_name='users' ORDER BY ordinal_position;"

echo
echo "############ 2) ⚠ 'sehir' GECEN HER KOLON — tum tablolarda ############"
$PSQL -c "
SELECT table_name, column_name, data_type
  FROM information_schema.columns
 WHERE column_name ILIKE '%sehir%' OR column_name ILIKE '%bolge%' OR column_name ILIKE '%il%'
 ORDER BY table_name, column_name;" | head -40

echo
echo "############ 3) ⚠ SUNUCU — 'sehirler' NEREDE islenıyor? ############"
grep -n 'sehirler' server_container.mjs | head -30 | sed 's/^/  /'

echo
echo "############ 4) ⚠ TEMSILCI KAYDET ENDPOINT'i — ne yaziyor? ############"
echo "  --- temsilci / rep PUT/POST rotalari ---"
grep -n "api/saha/temsilci\|api/saha/rep\|temsilciDetay\|/temsilciler" server_container.mjs | head -20 | sed 's/^/  /'

echo
echo "############ 5) ⚠ ARAYUZ — sehirler'i NEREYE gonderiyor? (saha.js) ############"
grep -n 'sehirler' shells/saha.js | head -20 | sed 's/^/  /'

echo
echo "############ 6) ⚠ users tablosunda jsonb kolon var mi? (sehir orada olabilir) ############"
$PSQL -c "
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_name='users' AND (data_type='jsonb' OR data_type='json');"
echo "  --- varsa: icinde sehir gecen kayit var mi? ---"
$PSQL -c "
SELECT full_name, metadata
  FROM users
 WHERE metadata::text ILIKE '%sehir%' OR metadata::text ILIKE '%KOCAEL%'
 LIMIT 5;" 2>/dev/null || echo "  (metadata kolonu yok ya da okunamadi)"

echo
echo "############ SONUC ############"
echo "  ⚠ sehir NEREDE saklaniyorsa, 9. adim ORAYI okumaliydi."
echo "  ⚠ Hicbir yerde degilse: temsilci sehir atama OZELLIGI CALISMIYOR demektir —"
echo "     arayuz var, kayit yok. O zaman eski diziyi oldurmek RISKSIZ."
