#!/bin/sh
# CRON_MULTITENANT_V1 — rep_ozellik: tum saha'li kiracilar (metrik_snapshot deseni)
PGP=$(docker exec krb-assessment printenv DATABASE_URL | sed -E 's#^[^:]+://[^:]+:([^@]+)@.*#\1#')
docker exec -i -e PGPASSWORD="$PGP" krb-assessment-postgres psql -U assessment_app -d assessment_platform -h 127.0.0.1 <<'SQL'
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT DISTINCT tenant_id AS t FROM rep_kimlik_koprusu WHERE durum='saha' LOOP
    PERFORM hesapla_rep_ozellik(r.t, current_date);
    PERFORM hesapla_rep_ozellik_ek(r.t, current_date);
    PERFORM hesapla_rep_ozellik_ek2(r.t, current_date);
  END LOOP;
END $$;
SQL
echo "[$(date '+%F %T')] rep_ozellik tamam (tum saha kiracilar)"
