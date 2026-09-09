#!/usr/bin/env bash
# DERIVE DEPLOY — kutsal deploy (build + compose --force-recreate) + OTOMATİK footprint.
# ⚠ docker cp YASAK; bu script sadece onaylı komutları çalıştırır + defter/deploy-log damgalar.
# Kullanım: bash deploy.sh "omurga_X: ne değişti"
set -euo pipefail
cd /opt/krb-assessment
ACIKLAMA="${1:-manuel deploy}"

echo "═══ 1/3 build ═══"
docker build -t krb-assessment:secure .
echo "═══ 2/3 compose up --force-recreate ═══"
docker compose up -d --force-recreate krb-assessment
echo "═══ 3/3 footprint (yetenek defteri + deploy-log) ═══"
bash /opt/krb-assessment/yetenek_footprint.sh "$ACIKLAMA" || echo "[deploy] footprint atlandı — deploy yine de başarılı"
echo "═══ DEPLOY TAMAM: $ACIKLAMA ═══"
