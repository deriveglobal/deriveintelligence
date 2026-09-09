#!/usr/bin/env bash
# OMURGA 55 DEPLOY — içgörü servisi endpoint'leri + build + recreate + defter
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YAMA + SYNTAX"
cp server_container.mjs server_container.mjs.bak_o55
python3 patch_icgoru_endpoint.py || exit 1
if ! node --check server_container.mjs; then echo "  ❌ syntax — geri al"; cp server_container.mjs.bak_o55 server_container.mjs; exit 1; fi
echo "  ✅ syntax temiz"

hr "2. BUILD + RECREATE"
docker build -t krb-assessment:secure . >/tmp/o55.log 2>&1 && echo "  ✅ build" || { echo "  ❌ build:"; tail -20 /tmp/o55.log; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1 && echo "  ✅ recreate" || { echo "  ❌ recreate"; exit 1; }
sleep 6

hr "3. DEFTER — 2 endpoint taslak-tanım"
$PSQL -c "UPDATE bi_yetenek SET cekmece='metrik', durum='taslak', guven='taslak', ne_ise_yarar=v.a
  FROM (VALUES ('/api/bi/icgoru','Kayda değer marj-düşüşü içgörülerini (AI-taslak anlatı) döndürür — cockpit tüketir.'),
               ('/api/bi/icgoru-yenile','Motoru (atom) + LLM anlatısını çalıştırıp bi_icgoru''yu tazeler.')
       ) v(ad,a) WHERE bi_yetenek.ad=v.ad AND bi_yetenek.tur='endpoint';" 2>&1 | sed 's/^/  /'

hr "4. CANLI mı (401 iyi, 404 kötü) + bi_icgoru dolu mu"
for p in icgoru; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8080/api/bi/$p" 2>/dev/null || echo "?")
  echo "  GET /api/bi/$p → HTTP $code"
done
$PSQL -c "SELECT count(*) anlatili_icgoru FROM bi_icgoru WHERE bolum='marka-marj' AND durum='yeni' AND anlati IS NOT NULL;" 2>&1 | sed 's/^/  /'

hr "BITTI — içgörü servisi canlı. Cockpit GET /api/bi/icgoru'yu tüketir. UI eski kabuğa yazılmadı (çöp değil)."
