#!/usr/bin/env bash
# TAZELIK_BEKCISI_CRON_V1 — gunluk: v_veri_tazelik ALARM'lari yakalar ve GORUNUR birakir.
#   ALARM varsa -> bi_insa_gunlugu'na TAZELIK_ALARM (CEO asistani selfCtx'te okur) + log'a gurultu.
#   Boylece besleme/hesap sessizce durursa ertesi sabah haberin olur (bir hafta degil).
set -uo pipefail
TS="$(date '+%F %T')"

# ALARM varsa gunde 1 kez insa gunlugune yaz (dedup: ayni gun tek satir)
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform >/dev/null 2>&1 <<'SQL'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'TAZELIK_ALARM',
       'Veri bayat: '||string_agg(kontrol||' '||gecikme_gun||'g', ', '),
       'v_veri_tazelik ALARM esigi asildi — besleme/hesap durmus olabilir (sessiz hata)',
       jsonb_build_object('kaynak','tazelik_bekcisi','alarmlar', jsonb_agg(kontrol))
  FROM v_veri_tazelik
 WHERE durum='ALARM'
   AND NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TAZELIK_ALARM' AND ts::date=CURRENT_DATE)
HAVING count(*) > 0;
SQL

CNT="$(docker exec -i krb-assessment-postgres psql -tA -U assessment_app -d assessment_platform -c \
  "SELECT count(*) FROM v_veri_tazelik WHERE durum='ALARM'" 2>/dev/null | tail -1)"
DETAY="$(docker exec -i krb-assessment-postgres psql -tA -U assessment_app -d assessment_platform -c \
  "SELECT string_agg(kontrol||' '||gecikme_gun||'g', ', ') FROM v_veri_tazelik WHERE durum='ALARM'" 2>/dev/null | tail -1)"

if [ "${CNT:-0}" -gt 0 ]; then
  echo "[$TS] ⚠ TAZELIK ALARM ($CNT): $DETAY — bi_insa_gunlugu'na yazildi (CEO asistani gorur)"
else
  echo "[$TS] OK: tum veri boruları taze"
fi
