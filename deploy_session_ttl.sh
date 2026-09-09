#!/usr/bin/env bash
# SESSION_TTL_V1 — rol-bazli sunucu oturum omru: yonetici/mudur 24s, saha temsilcisi 7g (onceki: sabit 14g).
#   Client AUTO_LOGOUT_V1 politikasini sunucuda da uygular. Fail-safe: rol sorgusu hata verirse rep TTL,
#   giris ASLA kirilmaz. Yalniz yeni girislerde etkili; mevcut oturumlar suresi dolunca yenilenir.
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_session_ttl.py ] || { echo "HATA: patch_session_ttl.py yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"
python3 patch_session_ttl.py "$S"
node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check — geri al"; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/sttl_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/sttl_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c SESSION_TTL_V1 /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c SESSION_TTL_V1 /app/server.mjs
echo "[bitti] Sunucu oturum omru rol-bazli (24s/7g). Test: normal login hala calisiyor mu, kontrol et."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
