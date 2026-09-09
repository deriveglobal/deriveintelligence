#!/bin/bash
PW=$(docker exec krb-assessment printenv DATABASE_URL | sed -E 's#.*://[^:]+:([^@]+)@.*#\1#')
R(){ docker exec -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app \
     -d assessment_platform -h 127.0.0.1 -X -c "$1"; }
R "SELECT bi_foto_gunluk();"
if [ "$(date +%u)" = "7" ]; then
  R "SELECT bi_foto_alacak_musteri();"
  R "SELECT * FROM bi_tahmin_sinif_uret();"
fi
