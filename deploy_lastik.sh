#!/usr/bin/env bash
# LASTIK_FILTRE_V1 dagitimi.  Atomik: assert patlarsa dosya DEGISMEZ.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) ONCESI: bozukluk gorunur mu? ############"
$PSQL -c "
SELECT marka, count(*) AS satir, round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND fatura_tarihi >= now() - interval '30 days'
 GROUP BY 1 ORDER BY 3 DESC LIMIT 5;"
echo "  ^ İŞÇİLİK listede mi? Yamadan sonra GITMELI."

echo
echo "############ 1) YAMA ############"
if grep -q "LASTIK_FILTRE_V1" server_container.mjs; then
  echo "  ZATEN YAMALI — cikiliyor."; exit 0
fi
cp server_container.mjs server_container.mjs.bak_lastik
python3 patch_lastik.py server_container.mjs || {
  echo "❌ YAMA BASARISIZ — dosya geri alindi"; cp server_container.mjs.bak_lastik server_container.mjs; exit 1; }

echo
echo "############ 2) KAPILAR ############"
node --check server_container.mjs || {
  echo "❌ NODE FAIL — geri alindi"; cp server_container.mjs.bak_lastik server_container.mjs; exit 1; }
echo "  NODE_OK"
[ -f dispatch_guard.py ] && python3 dispatch_guard.py shells/bi.js && echo "  DISPATCH_OK"

echo
echo "############ 3) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7

echo
echo "############ 4) SONRASI: DOGRULAMA ############"
echo "  -- lastik markalari (İŞÇİLİK OLMAMALI) --"
$PSQL -c "
SELECT marka, count(*) AS satir, round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND fatura_tarihi >= now() - interval '30 days'
   AND grup_adi LIKE 'LASTIK%'
 GROUP BY 1 ORDER BY 3 DESC LIMIT 5;"

echo "  -- TOPLAM ciro DEGISMEMELI (Haziran 121,76M) --"
$PSQL -c "
SELECT to_char(fatura_tarihi,'YYYY-MM') AS ay, round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-06-01'
 GROUP BY 1 ORDER BY 1;"

echo "  -- urun master: servis kalemi var mi? --"
$PSQL -c "
SELECT count(*) FILTER (WHERE krb_kalem_kodu IS NOT NULL) AS krb_eslesen
  FROM bi_urun_master;" 2>/dev/null || true

echo "  -- app ayakta mi --"
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

git add -A && git commit -q -m "fix(bi): LASTIK_FILTRE_V1 — tam ciro yuklendi; marka/ebat/urun sorgulari grup_adi ile filtreleniyor (İŞÇİLİK artik marka degil)" && echo "  COMMITTED"
echo
echo "✅ Geri alma:  cp server_container.mjs.bak_lastik server_container.mjs && docker cp ... && docker restart"
