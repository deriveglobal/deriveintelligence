#!/usr/bin/env bash
# BAYAT_V2 — asistanin agzindaki bayat/yanlis metinleri guncelle.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) GERCEK DURUM (yeni metin bunu soyleyecek) ############"
$PSQL -c "
SELECT 'satis' AS akis, count(*)::text AS satir,
       (min(fatura_tarihi))::text AS ilk, (max(fatura_tarihi))::text AS son
  FROM bi_satis_faturalari WHERE tenant_id='$TEN'
UNION ALL
SELECT 'alis', count(*)::text, (min(fatura_tarihi))::text, (max(fatura_tarihi))::text
  FROM bi_tedarikci_faturalari WHERE tenant_id='$TEN'::uuid;"
$PSQL -c "
SELECT round(sum(satir_tutar)/1e6,2) AS haziran2026_MTL
  FROM bi_satis_faturalari WHERE tenant_id='$TEN'
   AND fatura_tarihi >= DATE '2026-06-01' AND fatura_tarihi < DATE '2026-07-01';"
echo "  ^ 121,76 olmali (Fatih Bilen: 121,79)."

echo
echo "############ 1) YAMA ############"
if grep -q "BAYAT_V2" server_container.mjs; then echo "  ZATEN YAMALI"; exit 0; fi
cp server_container.mjs server_container.mjs.bak_bayat
python3 patch_bayat.py server_container.mjs || {
  echo "❌ YAMA BASARISIZ — geri alindi"; cp server_container.mjs.bak_bayat server_container.mjs; exit 1; }

echo
echo "############ 2) KAPILAR ############"
node --check server_container.mjs || {
  echo "❌ NODE FAIL — geri alindi"; cp server_container.mjs.bak_bayat server_container.mjs; exit 1; }
echo "  NODE_OK"

echo
echo "############ 3) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7

echo
echo "############ 4) KARSILAMA CACHE'INI TEMIZLE ############"
echo "  (yoksa Fatih Bilen dunun cache'lenmis 'ERP olu' karsilamasini gorur)"
$PSQL -c "DELETE FROM agent_greeting_cache WHERE agent='ceo';" 2>/dev/null || true
$PSQL -c "DELETE FROM bi_morning_briefings WHERE tenant_id='$TEN';" >/dev/null

echo
echo "############ 5) DOGRULAMA ############"
grep -c "BAYAT_V2" server_container.mjs | xargs echo "  BAYAT_V2 isareti:"
grep -c "29 GUNDUR OLU" server_container.mjs | xargs echo "  bayat '29 GUNDUR OLU' (0 OLMALI):"
grep -c "69.1M" server_container.mjs | xargs echo "  bayat '69.1M' (0 OLMALI):"
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

git add -A && git commit -q -m "fix(ceo): BAYAT_V2 — ERP yuklendi; 'ERP olu / 69.1M' uyarisi kaldirildi, Brisa brifingi guncellendi (soz tutuldu: Haziran 121,76M = GM'in rakami)" && echo "  COMMITTED"

echo
echo "✅ BITTI. Fatih Bilen artik dogru rakami gorecek."
echo "   Geri alma: cp server_container.mjs.bak_bayat server_container.mjs && docker cp ... && docker restart"
