#!/usr/bin/env bash
# OMURGA 14g — trendi net sermaye altına + DOĞRU verify (container div, getElementById değil). bi.js.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK"
cp shells/bi.js shells/bi.js.bak_trend7
echo "  ✅ .bak_trend7"

hr "2. TAŞI (ÖDEME TAKVİMİ etiketinden geriye en yakın if)"
python3 - <<'PY'
import sys
p='shells/bi.js'; u=open(p,encoding='utf-8').read()
CONTAINER = r'''h += '<div id="finans-trend-bolum" style="margin-top:28px"><div style="color:var(--tx-2);font-size:13px">Marka trendi yükleniyor…</div></div>';'''
MARK = "ÖDEME TAKVİMİ — dört ayda"
if u.count(CONTAINER)!=1: print("  ❌ container:",u.count(CONTAINER)); sys.exit(2)
if u.count(MARK)!=1: print("  ❌ etiket:",u.count(MARK)); sys.exit(2)
u = u.replace(CONTAINER, "", 1)
mp = u.index(MARK)
ifp = u.rindex("if (OD.length)", 0, mp)
u = u[:ifp] + CONTAINER + "\n      " + u[ifp:]
open(p,'w',encoding='utf-8').write(u)
print("  ✅ taşındı")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp shells/bi.js.bak_trend7 shells/bi.js; exit 1; fi

hr "3. SÖZDİZİMİ + DOĞRU KONUM (container div — margin-top:28px)"
cp shells/bi.js /tmp/_bic.mjs
node --check /tmp/_bic.mjs && echo "  ✅ sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp shells/bi.js.bak_trend7 shells/bi.js; exit 1; }
NET=$(grep -n "NET İŞLETME SERMAYESİ" shells/bi.js | head -1 | cut -d: -f1)
CONT=$(grep -n 'finans-trend-bolum" style="margin-top:28px' shells/bi.js | head -1 | cut -d: -f1)
ODE=$(grep -n "ÖDEME TAKVİMİ — dört ayda" shells/bi.js | head -1 | cut -d: -f1)
echo "  NET SERMAYE: $NET · CONTAINER DIV: $CONT · ÖDEME TAKVİMİ: $ODE"
echo "  --- container div bağlamı ---"
sed -n "$((CONT-2)),$((CONT+1))p" shells/bi.js | sed 's/^/    /'
if [ -n "$CONT" ] && [ "$CONT" -gt "$NET" ] && [ "$CONT" -lt "$ODE" ]; then
  echo "  ✅ container div net sermaye ile ödeme takvimi ARASINDA — DOĞRU"
else
  echo "  ❌ konum yanlış — geri al"; cp shells/bi.js.bak_trend7 shells/bi.js; exit 1
fi

hr "4. AYAK İZİ + DEPLOY"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_14g','Marka Trendi net sermaye altina + dogru verify','Mansset gorunur','{}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi"
echo "  ▶ DEPLOY: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — container div doğru konumda (bağlam yukarıda). Deploy."
