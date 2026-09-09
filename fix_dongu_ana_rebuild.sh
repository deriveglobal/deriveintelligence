#!/usr/bin/env bash
# DONGU_KANON_ANA_V1 — konteyner marker 0 duzeltme. COPY layer cache kirilir.
# Once teshis (Dockerfile COPY kaynagi + host marker), sonra no-cache rebuild.
set -uo pipefail
cd /opt/krb-assessment
SVC=krb-assessment
APP=krb-assessment

echo "=== HOST marker (2 beklenir) ==="
grep -c DONGU_KANON_ANA_V1 server_container.mjs

echo; echo "=== Dockerfile: COPY + server satirlari (COPY kaynagi neyi aliyor?) ==="
grep -niE 'COPY|server_container|server\.mjs|WORKDIR' Dockerfile 2>/dev/null || echo "Dockerfile yok?"

echo; echo "=== compose build context ==="
grep -niE 'build|context|dockerfile|image' docker-compose*.yml compose*.yml 2>/dev/null | head -20

echo; echo "=== KONTEYNER suanki marker (rebuild oncesi, 0 bekleniyor) ==="
docker exec "$APP" grep -c DONGU_KANON_ANA_V1 /app/server.mjs 2>/dev/null || true

echo; echo "=== no-cache rebuild (COPY cache kesin kirilir) ==="
docker compose build --no-cache "$SVC"
docker compose up -d --force-recreate "$SVC"
sleep 4

echo; echo "=== KONTEYNER marker (2 beklenir) ==="
docker exec "$APP" grep -c DONGU_KANON_ANA_V1 /app/server.mjs 2>/dev/null || true

echo; echo "=== canli uc kontrol: server.mjs ic hash + dongu satiri ==="
docker exec "$APP" grep -n 'DONGU_KANON_ANA_V1' /app/server.mjs 2>/dev/null | head -3 || true
