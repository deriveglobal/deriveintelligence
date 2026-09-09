#!/usr/bin/env bash
# SL_CONNECTOR cok-tenant cron (SL_MULTITENANT_V1).
# sl.d/*.env icindeki HER tenant icin sl_connector.py calistirir.
# Her env: SL_TENANT, SL_USER, SL_PASS, SL_BASE_URL. Anadolu gibi SL'siz tenant'in
# env dosyasi YOKtur -> otomatik atlanir. Arg (--dry / --only x) python'a gecer.
set -uo pipefail
D=/opt/krb-assessment/sl.d
shopt -s nullglob
found=0
for f in "$D"/*.env; do
  found=1
  ( set -a; . "$f"; set +a
    echo "════ [sl] tenant=${SL_TENANT:-?} base=${SL_BASE_URL:-default} $(date '+%F %T') ════"
    docker exec -e SL_USER -e SL_PASS -e SL_TENANT -e SL_BASE_URL krb-assessment python3 /app/sl_connector.py "$@" )
done
[ "$found" = 0 ] && echo "[sl] sl.d/ bos — hicbir tenant'ta SL yapilandirilmamis."
exit 0
