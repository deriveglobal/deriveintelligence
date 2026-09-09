#!/usr/bin/env bash
# İÇGÖRÜ BÖLÜMÜ + CAROUSEL keşfi — sebep motorunu nereye/nasıl bağlayacağım. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
F=shells/bi.js
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. icgoru_uret_finans fonksiyonu — ne üretiyor, nereye yazıyor"
$PSQL -c "SELECT pg_get_functiondef('icgoru_uret_finans'::regproc);" 2>&1 | head -70 | sed 's/^/  /'

hr "2. İçgörüler hangi tabloda + son kayıtlar"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name IN ('bi_icgoru','bi_sinyal') GROUP BY table_name;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT tip, count(*) FROM bi_sinyal WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid GROUP BY tip;" 2>&1 | sed 's/^/  /'

hr "3. CAROUSEL / içgörü kartı frontend (ok navigasyonu)"
grep -noiE "carousel|icgoru|içgörü|akilli|akıllı kart|ok tuşu|prev|next|›|‹|←|→|arrow" "$F" | head -25 | sed 's/^/  /'

hr "4. içgörü fetch endpoint'i (frontend nereden çekiyor)"
grep -noE "/api/[a-z/-]*icgoru[a-z/-]*|/api/[a-z/-]*insight[a-z/-]*|/api/[a-z/-]*sinyal[a-z/-]*|/api/[a-z/-]*kart[a-z/-]*" "$F" | head -15 | sed 's/^/  /'

hr "BITTI — içgörü motoru + carousel görülünce: sebep'i motora bağla + drill kartını 'sorulunca'ya çevir."
