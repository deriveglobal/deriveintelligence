#!/usr/bin/env bash
# DSO/stok trend için: backbone seri yapısı + mevcut finans-trend endpoint + UI fonksiyonu. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_metrik_gecmis — distinct metrik × boyut_tipi × güven (ne var)"
$PSQL -c "SELECT metrik, boyut_tipi, guven, count(*) nokta, min(donem)::text ilk, max(donem)::text son
          FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid GROUP BY 1,2,3 ORDER BY 1,2;" 2>&1 | sed 's/^/  /'

hr "2. DSO serisi — son 15 nokta (toplam boyut)"
$PSQL -c "SELECT donem::text, round(deger,1) dso, guven FROM bi_metrik_gecmis
          WHERE tenant_id='$T'::uuid AND metrik ILIKE '%dso%' AND boyut_tipi IN ('toplam','sirket','')
          ORDER BY donem DESC LIMIT 15;" 2>&1 | sed 's/^/  /'

hr "3. STOK serisi — son 15 nokta"
$PSQL -c "SELECT donem::text, round(deger/1e6,1) stok_m, guven FROM bi_metrik_gecmis
          WHERE tenant_id='$T'::uuid AND metrik ILIKE '%stok%' AND boyut_tipi IN ('toplam','sirket','')
          ORDER BY donem DESC LIMIT 15;" 2>&1 | sed 's/^/  /'

hr "4. Mevcut /api/bi/finans-trend endpoint (tam)"
grep -n "finans-trend" server_container.mjs | sed 's/^/  /'
START=$(grep -n "url.pathname === '/api/bi/finans-trend'" server_container.mjs | head -1 | cut -d: -f1)
if [ -n "$START" ]; then sed -n "${START},$((START+70))p" server_container.mjs; fi

hr "5. UI — _finansTrendCiz fonksiyonu (tam) + nereden çağrılıyor"
grep -n "_finansTrendCiz\|finans-trend-bolum" shells/bi.js | sed 's/^/  /'

hr "BITTI"
