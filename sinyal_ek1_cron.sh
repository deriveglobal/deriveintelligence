#!/bin/sh
# CRON_MULTITENANT_SINYAL_EK1_V1 — sinyal_motor_ek1 (rep x kategori) TUM saha'li kiracilar icin.
PGP=$(docker exec krb-assessment printenv DATABASE_URL | sed -E 's#^[^:]+://[^:]+:([^@]+)@.*#\1#')
RUN="docker exec -i -e PGPASSWORD=$PGP krb-assessment-postgres psql -U assessment_app -d assessment_platform -h 127.0.0.1"
TENANTS=$(docker exec -e PGPASSWORD="$PGP" krb-assessment-postgres psql -U assessment_app -d assessment_platform -h 127.0.0.1 -tAc "SELECT DISTINCT tenant_id FROM rep_kimlik_koprusu WHERE durum='saha' AND user_id IS NOT NULL")
for T in $TENANTS; do
  [ -z "$T" ] && continue
  sed '/^\\set t /d' /opt/krb-assessment/sinyal_motor_ek1.sql | $RUN -v t="$T" -v ON_ERROR_STOP=0 >/dev/null 2>&1
  echo "  sinyal_ek1: $T"
done
echo "[$(date '+%F %T')] sinyal_ek1 tamam (tum saha kiracilar)"
