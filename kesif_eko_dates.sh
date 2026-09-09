#!/usr/bin/env bash
# DÖVİZ çekmecesi tarih kapsamı — 12-aylık pencereyi tutuyor mu. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_ekonomik_parametreler — tarih aralığı + kaç ay"
$PSQL -c "SELECT min(gecerli_tarih) ilk, max(gecerli_tarih) son, count(*), count(DISTINCT date_trunc('month',gecerli_tarih)) ay_sayisi FROM bi_ekonomik_parametreler;" 2>&1 | sed 's/^/  /'

hr "2. usd_try zaman serisi (pencere: 9 ay önce vs 3 ay önce)"
$PSQL -c "SELECT to_char(gecerli_tarih,'YYYY-MM-DD') t, usd_try, lastik_fiyat_artis_yillik_pct lastik FROM bi_ekonomik_parametreler ORDER BY gecerli_tarih;" 2>&1 | sed 's/^/  /'

hr "3. Pencere uçlarına en yakın kayıtlar (v5 bunları seçecek)"
$PSQL -c "SELECT '9ay önce' etiket, to_char(gecerli_tarih,'YYYY-MM-DD') t, usd_try FROM bi_ekonomik_parametreler ORDER BY abs(gecerli_tarih-(date_trunc('month',CURRENT_DATE)-interval '9 month')::date) LIMIT 1;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT '3ay önce' etiket, to_char(gecerli_tarih,'YYYY-MM-DD') t, usd_try FROM bi_ekonomik_parametreler ORDER BY abs(gecerli_tarih-(date_trunc('month',CURRENT_DATE)-interval '3 month')::date) LIMIT 1;" 2>&1 | sed 's/^/  /'

hr "4. 'zam'→'zamanında' tuzağı doğrula"
$PSQL -c "SELECT (ARRAY['Sezer zamanında ödeyecek'] @> ARRAY['x'])::text placeholder;" >/dev/null 2>&1
$PSQL -c "SELECT 'zamanında ödeyecek' ILIKE '%zam%' AS zam_tuzagi;" 2>&1 | sed 's/^/  /'

hr "BITTI — döviz kapsamı + tuzak. v5 buna göre."
