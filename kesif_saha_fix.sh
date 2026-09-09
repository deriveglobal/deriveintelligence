#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
S=/opt/krb-assessment/server_container.mjs
S2=/opt/krb-assessment/shells
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. shells/ dosyalari (saha frontend hangisi)"
ls -la "$S2"

hr "2. JS BUG lokasyonlari"
grep -rn "kapatModal" "$S2" 2>/dev/null | head -8
grep -rn "_piyasaOzetLoaded" "$S2" 2>/dev/null | head -8
grep -rn "det-yorum" "$S2" 2>/dev/null | head -8
grep -rn "rep-brain" "$S2" 2>/dev/null | head -8

hr "3. SERVER endpoint kodu (routing anahtarlari)"
grep -nE "yorumlar|rep-brain|musteri-destek|Bilinmeyen saha endpoint" "$S" | head -30
grep -nE "request\.json" "$S" | head -10

hr "4. YAVAS_API — hangi endpoint yavas"
$PSQL -c "SELECT endpoint, count(*) n, round(avg(duration_ms)) ort_ms, max(duration_ms) max_ms FROM saha_hata_log WHERE tip='YAVAS_API' GROUP BY 1 ORDER BY 2 DESC LIMIT 15;"

hr "5. REP ONERILERI (ts ile — B duzeltme)"
$PSQL -c "SELECT ts::date, kategori, baslik, left(mesaj,110) mesaj, durum FROM saha_oneri ORDER BY ts DESC LIMIT 25;"
