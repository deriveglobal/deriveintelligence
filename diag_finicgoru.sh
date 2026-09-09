#!/usr/bin/env bash
# READ-ONLY diag — AI finansal içgörü neden üretilmedi? Tablo + API key + geniş loglar.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"

echo "=== 1) tablo durumu ==="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT to_char(gun,'YYYY-MM-DD') gun, jsonb_array_length(icgoruler) n, to_char(uretildi_at,'HH24:MI:SS') uretim FROM bi_finansal_icgoru ORDER BY uretildi_at DESC LIMIT 5;"

echo ""
echo "=== 2) ANTHROPIC_API_KEY konteynerde var mı? ==="
docker exec krb-assessment sh -c 'test -n "$ANTHROPIC_API_KEY" && echo KEY_SET || echo KEY_MISSING'

echo ""
echo "=== 3) fin-icgoru / icgoru / Error logları (son 600 satır) ==="
docker logs --tail 600 krb-assessment 2>&1 | grep -iE "fin-icgoru|finansal|icgoru|anthropic|unhandled|Error:" | tail -25 || echo "(eşleşen log yok)"

echo ""
echo "=== 4) en son 15 log satırı (genel) ==="
docker logs --tail 15 krb-assessment 2>&1 | tail -15
echo "== DONE =="
