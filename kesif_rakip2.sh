#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
S=/opt/krb-assessment/server_container.mjs
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "A. SAYIM + TAZELIK"
$PSQL -c "SELECT 'rakip_fiyat_son' t, count(*) n, max(scraped_at)::text taze FROM bi_rakip_fiyat_son
UNION ALL SELECT 'rakip_fiyat', count(*), max(scraped_at)::text FROM bi_rakip_fiyat
UNION ALL SELECT 'price_monitor', count(*), max(scraped_at)::text FROM bi_price_monitor
UNION ALL SELECT 'alarm_unseen', count(*) FILTER (WHERE NOT goruldu), max(alarm_at)::text FROM bi_rakip_fiyat_alarm
UNION ALL SELECT 'izle_aktif', count(*) FILTER (WHERE aktif), NULL FROM bi_rakip_izle;"

hr "B. TENANT DAGILIMI"
$PSQL -c "SELECT tenant_id, count(*) FROM bi_rakip_fiyat_son GROUP BY 1 ORDER BY 2 DESC LIMIT 5;"
$PSQL -c "SELECT tenant_id::text, count(*) FROM bi_price_monitor GROUP BY 1 ORDER BY 2 DESC LIMIT 5;"

hr "C. bi_price_monitor ORNEK"
$PSQL -c "SELECT kalem_kodu, marka, ebat, krb_fiyat, rakip_adi, rakip_fiyat, fiyat_farki_pct, scraped_at::date FROM bi_price_monitor ORDER BY scraped_at DESC NULLS LAST LIMIT 8;"

hr "D. /api/rakip tid cozumu + ozet govdesi"
sed -n '20300,20320p;20686,20720p' "$S"

hr "E. /api/rakip/piyasa govdesi"
sed -n '20382,20440p' "$S"
