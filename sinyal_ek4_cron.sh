#!/bin/sh
PGP=$(docker exec krb-assessment printenv DATABASE_URL | sed -E 's#^[^:]+://[^:]+:([^@]+)@.*#\1#')
RUN="docker exec -i -e PGPASSWORD=$PGP krb-assessment-postgres psql -U assessment_app -d assessment_platform -h 127.0.0.1"
TENANTS=$(docker exec -e PGPASSWORD="$PGP" krb-assessment-postgres psql -U assessment_app -d assessment_platform -h 127.0.0.1 -tAc "SELECT DISTINCT tenant_id FROM bi_satis_faturalari WHERE satir_tutar>0")
for T in $TENANTS; do
  [ -z "$T" ] && continue
  sed '/^\\set t /d' /opt/krb-assessment/sinyal_motor_ek4.sql | $RUN -v t="$T" -v ON_ERROR_STOP=0 >/dev/null 2>&1
done
echo "[$(date '+%F %T')] sinyal_ek4 tamam"
