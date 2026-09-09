#!/usr/bin/env bash
# KEŞİF — Veri odası render fonksiyonu + alarm tablo yapısı + endpoint deseni. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. Veri odası render fonksiyonu (ciz_veri / veri govde / sekme)"
grep -nE "ciz_veri|veri-govde|veri_govde|'veri'|\"veri\"|Veri Kalitesi|VERİ ODAS|data-oda=.?veri" shells/bi.js | head -25 | sed 's/^/  /'

hr "2. bi_saglik_alarm kolonları + durum dağılımı"
$PSQL -c "\d bi_saglik_alarm" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT tip, durum, count(*) FROM bi_saglik_alarm WHERE tenant_id='$T'::uuid GROUP BY 1,2 ORDER BY 1,2;" 2>&1 | sed 's/^/  /'

hr "3. bi_bilinen_deger kolonları (kabul edilen alarm buraya yazılacak)"
$PSQL -c "\d bi_bilinen_deger" 2>&1 | sed 's/^/  /'

hr "4. Endpoint deseni — mevcut bir /api/bi GET route örneği (ilk 2)"
grep -nE "url.pathname === '/api/bi/" server_container.mjs | head -8 | sed 's/^/  /'

hr "5. bi.js — bir 'oda' sekme çiziminin nasıl fetch+render ettiği (örnek ciz_ fonksiyonu iskeleti)"
grep -nE "async function ciz_|function ciz_" shells/bi.js | head -20 | sed 's/^/  /'

hr "BITTI"
