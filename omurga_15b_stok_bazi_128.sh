#!/usr/bin/env bash
# OMURGA 15b (#128) — SADECE finans endpoint'inin stok bazını ağırlıklı ortalamaya. Route-scoped.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK"
cp server_container.mjs server_container.mjs.bak_128b
echo "  ✅ .bak_128b"

hr "2. YAMA (finans route'una sabitlenmiş sa CTE değişimi)"
python3 - <<'PY'
import sys
p='server_container.mjs'; s=open(p,encoding='utf-8').read()
ROUTE = "url.pathname === '/api/bi/finans'"
MARK  = "SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))"
if s.count(ROUTE)!=1: print("  ❌ finans route sayisi:",s.count(ROUTE)); sys.exit(2)
froute = s.index(ROUTE)
# finans route'undan SONRAKİ ilk marker = finans'ın stok CTE'si
mi = s.index(MARK, froute)
# aynı bölgede WITH sa AS ( — route ile marker arası
sa_start = s.rindex("WITH sa AS (", froute, mi)
sa_end   = s.index("stok AS (", mi)
NEW = ("WITH sa AS (\n"
       "              SELECT bi_sku_norm(kalem_kodu) AS sku,\n"
       "                     sum(giris_tutari) / NULLIF(sum(giris),0) AS fiyat\n"
       "                FROM bi_stok_hareket\n"
       "               WHERE tenant_id=$1::uuid AND giris>0\n"
       "               GROUP BY bi_sku_norm(kalem_kodu)),\n"
       "            ")
s = s[:sa_start] + NEW + s[sa_end:]
open(p,'w',encoding='utf-8').write(s)
print("  ✅ finans sa CTE ağırlıklı ortalamaya çevrildi (diğer endpoint dokunulmadı)")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp server_container.mjs.bak_128b server_container.mjs; exit 1; fi

hr "3. SÖZDİZİMİ + DEĞİŞİKLİK"
node --check server_container.mjs && echo "  ✅ sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp server_container.mjs.bak_128b server_container.mjs; exit 1; }
echo "  DISTINCT ON kalan (diğer endpoint — 1 olmalı): $(grep -c 'SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))' server_container.mjs)"
echo "  ağırlıklı ort eklendi (1 olmalı): $(grep -c 'sum(giris_tutari) / NULLIF(sum(giris),0)' server_container.mjs)"

hr "4. AYAK İZİ + DEPLOY"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_15_#128','finans stok bazi -> agirlikli ortalama (route-scoped)','Ekran NET 74->41M kanonik','{}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi"
echo "  ▶ DEPLOY: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — finans stok bazı düzeltildi (diğer endpoint korundu). Deploy."
