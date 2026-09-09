#!/usr/bin/env bash
# READ-ONLY — AI finansal içgörü üretimini doğrula: tablo satırı + içgörü sayısı + son loglar.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
echo "=== bi_finansal_icgoru satırları (gün · içgörü adedi · üretim) ==="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT to_char(gun,'YYYY-MM-DD') gun, jsonb_array_length(icgoruler) icgoru_adet, to_char(uretildi_at,'HH24:MI:SS') uretim FROM bi_finansal_icgoru ORDER BY uretildi_at DESC LIMIT 3;"
echo ""
echo "=== ilk içgörünün başlığı + etki (varsa) ==="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT icgoruler->0->>'baslik' baslik, icgoruler->0->>'etki_tl' etki_tl, icgoruler->0->>'siddet' siddet FROM bi_finansal_icgoru ORDER BY uretildi_at DESC LIMIT 1;"
echo ""
echo "=== son fin-icgoru logları ==="
docker logs --tail 200 krb-assessment 2>&1 | grep -i "fin-icgoru" | tail -10 || echo "(log yok — henüz üretilmemiş olabilir)"
echo "== DONE =="
