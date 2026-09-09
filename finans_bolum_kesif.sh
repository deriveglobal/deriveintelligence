#!/usr/bin/env bash
# ciz_finans BÖLÜM SINIRLARI — trendi Net İşletme Sermayesi'nin altına koymak için anchor bul. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ciz_finans içindeki bölüm başlıkları (h += ... etiket ...) — sıra"
FN=$(grep -n "async function ciz_finans" shells/bi.js | cut -d: -f1)
END=$((FN+120))
awk -v a="$FN" -v b="$END" 'NR>=a && NR<=b && /h \+=/ && (/etiket/ || /TAKV/ || /SERMAYES/ || /KRED/ || /RİSKL/ || /RISKL/ || /finans-trend/){print NR": "$0}' shells/bi.js | sed 's/^/  /'

hr "2. NET SERMAYE kartının KAPANIŞI + ÖDEME TAKVİMİ başlangıcı (bağlam)"
L=$(awk -v a="$FN" 'NR>=a && /ÖDEME TAKV|ODEME TAKV|TAKVİM|TAKVIM/{print NR; exit}' shells/bi.js || true)
echo "  ödeme takvimi başlığı ~satır: ${L:-bulunamadı}"
[ -n "${L:-}" ] && sed -n "$((L-4)),$((L+2))p" shells/bi.js | sed 's/^/  /'

hr "3. Mevcut trend container satırı (taşınacak olan)"
grep -n 'h += .<div id="finans-trend-bolum' shells/bi.js | sed 's/^/  /'

hr "BITTI — net sermaye sonrası anchor görüldü, trend oraya taşınır."
