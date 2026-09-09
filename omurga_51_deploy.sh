#!/usr/bin/env bash
# OMURGA 51 DEPLOY — sebep anlatısı ekrana: endpoint + kart yaması + build + recreate
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK + YAMA"
cp server_container.mjs server_container.mjs.bak_o51
cp shells/bi.js shells/bi.js.bak_o51
python3 patch_sebep_endpoint.py || exit 1
python3 patch_sebep_card.py || exit 1

hr "2. SYNTAX (server + bi.js) — kırıksa geri al"
if ! node --check server_container.mjs; then echo "  ❌ server syntax"; cp server_container.mjs.bak_o51 server_container.mjs; exit 1; fi
if ! node --check shells/bi.js; then echo "  ❌ bi.js syntax"; cp shells/bi.js.bak_o51 shells/bi.js; cp server_container.mjs.bak_o51 server_container.mjs; exit 1; fi
echo "  ✅ ikisi de temiz"
echo -n "  bi.js hash: "; md5sum shells/bi.js | cut -c1-10

hr "3. BUILD + RECREATE"
docker build -t krb-assessment:secure . >/tmp/o51.log 2>&1 && echo "  ✅ build" || { echo "  ❌ build:"; tail -20 /tmp/o51.log; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1 && echo "  ✅ recreate" || { echo "  ❌ recreate"; exit 1; }
sleep 6

hr "4. DEFTER — yeni endpoint taslak-tanım"
$PSQL -c "UPDATE bi_yetenek SET ne_ise_yarar='Marka marj-düşüş sebebini insan-sesli anlatı olarak döndürür (sebep_arastir_marj + açık kök-soru).', cekmece='metrik', durum='taslak', guven='taslak' WHERE ad='/api/bi/finans-marka-sebep' AND tur='endpoint';" 2>&1 | sed 's/^/  /'

hr "5. SAĞLIK + endpoint canlı mı (auth beklenir=200/401, 404 OLMAMALI)"
docker ps --filter name=krb-assessment --format '  {{.Names}} {{.Status}}'
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8080/api/bi/finans-marka-sebep?marka=CONTINENTAL" 2>/dev/null || echo "?")
echo "  /api/bi/finans-marka-sebep → HTTP $code (401/200 iyi, 404 kötü)"

hr "BITTI — Finans → marka drill'de 💡 SEBEP anlatısı + kök-neden tıkla-cevapla görünmeli."
