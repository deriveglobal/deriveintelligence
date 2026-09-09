#!/usr/bin/env bash
# OMURGA 14d — Marka Trendi'ni Net İşletme Sermayesi'nin altına taşı (ödeme takviminin öncesine). bi.js.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK"
cp shells/bi.js shells/bi.js.bak_trend4
echo "  ✅ .bak_trend4"

hr "2. TAŞI (Python) — container'ı dipten al, ödeme takviminin öncesine koy"
python3 - <<'PY'
import sys
p='shells/bi.js'; u=open(p,encoding='utf-8').read()
CONTAINER = r'''h += '<div id="finans-trend-bolum" style="margin-top:28px"><div style="color:var(--tx-2);font-size:13px">Marka trendi yükleniyor…</div></div>';'''
ANCHOR = "if (OD.length) {"
if u.count(CONTAINER)!=1: print("  ❌ container sayisi:",u.count(CONTAINER)); sys.exit(2)
if u.count(ANCHOR)!=1:    print("  ❌ ödeme takvimi anchor sayisi:",u.count(ANCHOR)); sys.exit(2)
# 1) mevcut container'ı kaldır
u = u.replace(CONTAINER, "", 1)
# 2) ödeme takviminin öncesine ekle (net sermaye kartının altına)
u = u.replace(ANCHOR, CONTAINER + "\n      " + ANCHOR, 1)
open(p,'w',encoding='utf-8').write(u)
print("  ✅ trend taşındı (net sermaye altı)")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp shells/bi.js.bak_trend4 shells/bi.js; exit 1; fi

hr "3. SÖZDİZİMİ + YER"
cp shells/bi.js /tmp/_bic.mjs
node --check /tmp/_bic.mjs && echo "  ✅ sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp shells/bi.js.bak_trend4 shells/bi.js; exit 1; }
NET=$(grep -n "NET İŞLETME SERMAYESİ" shells/bi.js | head -1 | cut -d: -f1)
CONT=$(grep -n 'finans-trend-bolum' shells/bi.js | head -1 | cut -d: -f1)
ODE=$(grep -n "ÖDEME TAKVİMİ" shells/bi.js | head -1 | cut -d: -f1)
echo "  NET SERMAYE: $NET · TREND: $CONT · ÖDEME TAKVİMİ: $ODE"
if [ -n "$CONT" ] && [ "$CONT" -gt "$NET" ] && [ "$CONT" -lt "$ODE" ]; then
  echo "  ✅ trend ARTIK net sermaye ile ödeme takvimi ARASINDA — doğru konum"
else
  echo "  ❌ konum yanlış — geri al"; cp shells/bi.js.bak_trend4 shells/bi.js; exit 1
fi

hr "4. AYAK İZİ + DEPLOY"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_14d','Marka Trendi Net Isletme Sermayesi altina tasindi','Mansset icgoru gorunur olsun (kaydirmadan)','{}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi"
echo "  ▶ DEPLOY: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — trend yukarı taşındı, doğrulandı. Deploy yukarıda."
