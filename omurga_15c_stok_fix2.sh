#!/usr/bin/env bash
# OMURGA 15c (#128 düzeltme2) — sa+stok CTE'yi HAM kalem_kodu join'e çevir (kanonik 235,4M). server.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. BEKLENEN DEĞER — kanonik ham-join stok (deploy sonrası ekran bunu göstermeli)"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
WITH km AS (SELECT kalem_kodu, sum(giris_tutari) gt, sum(giris) g FROM bi_stok_hareket WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid AND giris>0 GROUP BY kalem_kodu)
SELECT round(sum(a.adet*(km.gt/km.g))/1e6,1) beklenen_stok_m
  FROM bi_stok_anlik a JOIN km ON km.kalem_kodu=a.kalem_kodu
 WHERE a.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid AND a.adet>0
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid);"

hr "1. YEDEK"
cp server_container.mjs server_container.mjs.bak_128c
echo "  ✅ .bak_128c"

hr "2. YAMA — finans sa+stok CTE'sini ham kalem_kodu ile değiştir"
python3 - <<'PY'
import sys
p='server_container.mjs'; s=open(p,encoding='utf-8').read()
ROUTE="url.pathname === '/api/bi/finans'"
if s.count(ROUTE)!=1: print("  ❌ route:",s.count(ROUTE)); sys.exit(2)
fr=s.index(ROUTE)
sa_start=s.index("WITH sa AS (", fr)
al_start=s.index("alacak AS (", sa_start)
NEW=("WITH sa AS (\n"
     "              SELECT kalem_kodu, sum(giris_tutari) AS gt, sum(giris) AS g\n"
     "                FROM bi_stok_hareket\n"
     "               WHERE tenant_id=$1::uuid AND giris>0\n"
     "               GROUP BY kalem_kodu),\n"
     "            stok AS (\n"
     "              SELECT COALESCE(sum(st.adet*(sa.gt/sa.g)),0) AS deger\n"
     "                FROM bi_stok_anlik st\n"
     "                JOIN sa ON sa.kalem_kodu = st.kalem_kodu\n"
     "               WHERE st.tenant_id=$1::uuid AND st.adet>0\n"
     "                 AND st.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id=$1::uuid)),\n"
     "            ")
s=s[:sa_start]+NEW+s[al_start:]
open(p,'w',encoding='utf-8').write(s)
print("  ✅ sa+stok ham kalem_kodu join'e çevrildi")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp server_container.mjs.bak_128c server_container.mjs; exit 1; fi

hr "3. SÖZDİZİMİ + DEĞİŞİKLİK"
node --check server_container.mjs && echo "  ✅ sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp server_container.mjs.bak_128c server_container.mjs; exit 1; }
echo "  bi_sku_norm join kalktı mı (finans stok'ta 0 olmalı): $(grep -c 'sa.sku = bi_sku_norm' server_container.mjs)"
echo "  ham join var mı: $(grep -c 'JOIN sa ON sa.kalem_kodu = st.kalem_kodu' server_container.mjs)"

hr "4. AYAK İZİ + DEPLOY"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_15c_#128fix','finans stok join bi_sku_norm -> ham kalem_kodu','177M/-17M bug: kanonik 235M/41M','{}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi"
echo "  ▶ DEPLOY: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — §0'daki beklenen ~235M. Deploy sonrası ekran STOK 235M / NET 41M olmalı."
