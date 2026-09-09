#!/usr/bin/env bash
# OMURGA 14e — trendi Net İşletme Sermayesi altına taşı (DOĞRU anchor: var _tp öncesi if). bi.js.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK"
cp shells/bi.js shells/bi.js.bak_trend5
echo "  ✅ .bak_trend5"

hr "2. TAŞI (Python — var _tp öncesindeki if'e)"
python3 - <<'PY'
import sys
p='shells/bi.js'; u=open(p,encoding='utf-8').read()
CONTAINER = r'''h += '<div id="finans-trend-bolum" style="margin-top:28px"><div style="color:var(--tx-2);font-size:13px">Marka trendi yükleniyor…</div></div>';'''
if u.count(CONTAINER)!=1: print("  ❌ container:",u.count(CONTAINER)); sys.exit(2)
if u.count("var _tp = 0;")!=1: print("  ❌ var _tp:",u.count("var _tp = 0;")); sys.exit(2)
# 1) dipteki container'ı kaldır
u = u.replace(CONTAINER, "", 1)
# 2) ödeme takviminin if'inin (var _tp'den hemen önceki) ÖNÜNE koy
tp = u.index("var _tp = 0;")
ifp = u.rindex("if (OD.length)", 0, tp)
u = u[:ifp] + CONTAINER + "\n      " + u[ifp:]
open(p,'w',encoding='utf-8').write(u)
print("  ✅ taşındı (ödeme takvimi if'inin önüne)")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp shells/bi.js.bak_trend5 shells/bi.js; exit 1; fi

hr "3. SÖZDİZİMİ + KONUM DOĞRULAMA"
cp shells/bi.js /tmp/_bic.mjs
node --check /tmp/_bic.mjs && echo "  ✅ sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp shells/bi.js.bak_trend5 shells/bi.js; exit 1; }
NET=$(grep -n "NET İŞLETME SERMAYESİ" shells/bi.js | head -1 | cut -d: -f1)
CONT=$(grep -n 'finans-trend-bolum' shells/bi.js | head -1 | cut -d: -f1)
ODE=$(grep -n "ÖDEME TAKVİMİ" shells/bi.js | head -1 | cut -d: -f1)
echo "  NET SERMAYE: $NET · TREND: $CONT · ÖDEME TAKVİMİ: $ODE"
if [ -n "$CONT" ] && [ "$CONT" -gt "$NET" ] && [ "$CONT" -lt "$ODE" ]; then
  echo "  ✅ trend net sermaye ile ödeme takvimi ARASINDA — doğru"
else
  echo "  ❌ konum yanlış — geri al"; cp shells/bi.js.bak_trend5 shells/bi.js; exit 1
fi

hr "4. AYAK İZİ + DEPLOY"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_14e','Marka Trendi Net Isletme Sermayesi altina (dogru anchor)','Mansset gorunur','{}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi"
echo "  ▶ DEPLOY: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — trend doğru konumda, doğrulandı. Deploy yukarıda."
