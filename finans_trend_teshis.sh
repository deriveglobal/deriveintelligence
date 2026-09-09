#!/usr/bin/env bash
# TEŞHİS — trend eklemeleri bi.js'te NEREYE düştü (ciz_finans içinde mi, yanlış fonksiyonda mı). OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ciz_finans başlangıç + commit satırları"
grep -n "async function ciz_finans" shells/bi.js | sed 's/^/  ciz_finans def: /'
echo "  --- ciz_finans içindeki .dn ve g.innerHTML=h satırları ---"
awk 'NR>=649 && NR<=760 && (/g\.querySelectorAll\(.\.dn/ || /g\.innerHTML = h;/){print NR": "$0}' shells/bi.js | sed 's/^/  /'

hr "2. finans-trend-bolum eklemeleri NEREDE (satır no + bağlam)"
grep -n "finans-trend-bolum" shells/bi.js | sed 's/^/  /'
echo "  --- her birinin bağlamı (±2 satır) ---"
for L in $(grep -n "finans-trend-bolum" shells/bi.js | cut -d: -f1); do
  echo "  ▼ satır $L:"; sed -n "$((L-2)),$((L+1))p" shells/bi.js | sed 's/^/    /'
done

hr "3. _finansTrendCiz tanım + çağrı NEREDE"
grep -n "_finansTrendCiz" shells/bi.js | sed 's/^/  /'

hr "4. KARAR — container 'h +=' ciz_finans aralığında (649-760) mı?"
CONT=$(grep -n "h += '<div id=\"finans-trend-bolum" shells/bi.js | head -1 | cut -d: -f1 || true)
echo "  container h+= satır: ${CONT:-YOK}"
if [ -n "${CONT:-}" ] && [ "$CONT" -ge 649 ] && [ "$CONT" -le 780 ]; then
  echo "  ✅ ciz_finans içinde — sorun başka (fetch/DOM). Konsol bakılmalı."
else
  echo "  ❌ ciz_finans DIŞINDA — yanlış fonksiyona düştü. Geri al + doğru anchor'la yeniden."
fi

hr "BITTI — nereye düştüğü net. Buna göre düzeltiriz."
