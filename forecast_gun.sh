#!/bin/bash
PW=$(docker exec krb-assessment printenv DATABASE_URL | sed -E 's#.*://[^:]+:([^@]+)@.*#\1#')
docker exec -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app \
  -d assessment_platform -h 127.0.0.1 -X -c "SELECT bi_forecast_gunluk();"
docker exec -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app \
  -d assessment_platform -h 127.0.0.1 -X -c \
  "SELECT * FROM bi_tahmin_canli_uret_ufuk((date_trunc('month',CURRENT_DATE)+interval '1 month')::date, 2);"
