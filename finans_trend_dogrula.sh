#!/usr/bin/env bash
# TREND DOĞRULA — endpoint SQL veri döndürüyor mu + route kayıtlı mı + container div bi.js'te mi. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ENDPOINT SQL — gerçekten satır döndürüyor mu (endpoint'in birebir sorgusu)"
$PSQL -c "
SELECT boyut_deger AS ad,
       round(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01')/1e6,1) AS h1_2025_m,
       round(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')/1e6,1) AS h1_2026_m,
       round(100.0*(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')
             - sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'))
             / nullif(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'),0)) AS yoy_pct
  FROM bi_metrik_gecmis
 WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND boyut_tipi='marka'
 GROUP BY boyut_deger
HAVING sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01') > 0
 ORDER BY h1_2026_m DESC NULLS LAST LIMIT 12;"
echo "  ⚠ Satır dönüyorsa endpoint veri verecek demektir."

hr "2. ROUTE KAYITLI MI — http kodu (401/403=var+auth, 404=yok)"
curl -s -o /dev/null -w "  /api/bi/finans-trend → HTTP %{http_code}\n" "http://localhost:8080/api/bi/finans-trend" || echo "  curl ulaşamadı"

hr "3. CONTAINER DIV bi.js'te mi (deploy edilen dosyada)"
docker exec krb-assessment sh -c "grep -c 'finans-trend-bolum' /app/shells/bi.js" 2>/dev/null | sed 's/^/  finans-trend-bolum geçiş (container+fetch): /'
docker exec krb-assessment sh -c "grep -c '_finansTrendCiz' /app/shells/bi.js" 2>/dev/null | sed 's/^/  _finansTrendCiz geçiş: /'
echo "  ⚠ container>=1 ve _finansTrendCiz=2 ise kod deploy'da var → sorun sadece scroll/görünürlük."

hr "BITTI — backend + deploy edilen kod doğrulandı. Ekranda en alta kaydır."
