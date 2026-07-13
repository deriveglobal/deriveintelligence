#!/usr/bin/env bash
# AYKIRI_V1 — aykiri satislar araliktan cikar, tiklaninca gorunur.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) SORUN — su an ekranda ne yaziyor? ############"
$PSQL -c "
SELECT 'HAM (aykirilar DAHIL)' AS hesap,
       ROUND(MIN(birim_fiyat))  AS min_TL,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS medyan_TL,
       ROUND(MAX(birim_fiyat))  AS max_TL,
       COUNT(*)::int AS satis
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND ebat='385/65R22.5' AND upper(marka)='BRIDGESTONE'
   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat>0
   AND fatura_tarihi >= date_trunc('year',CURRENT_DATE);"
echo "  ^ min 339 TL — medyan 18.125 olan kamyon lastigi icin ANLAMSIZ."

echo
echo "############ 1) YAMA: sunucu ############"
if grep -q "AYKIRI_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_aykiri
  python3 patch_aykiri.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_aykiri server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_aykiri server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 2) SQL'i POSTGRES'E DOGRULAT ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT musteri_adi, birim_fiyat, fatura_tarihi, fatura_no, miktar, satis_temsilcisi
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN'::text AND ebat='385/65R22.5' AND upper(marka)=upper('BRIDGESTONE')
   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 AND birim_fiyat < 5437
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
 ORDER BY birim_fiyat ASC LIMIT 50;" >/dev/null \
 && echo "  SQL_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_aykiri server_container.mjs; exit 1; }

echo
echo "############ 3) YAMA: ekran ############"
cp shells/saha.js shells/saha.js.bak_aykiri
ONCE=$(wc -c < shells/saha.js)
if grep -q "AYKIRI_UI_V1" shells/saha.js; then echo "  ZATEN YAMALI"; else
  python3 patch_aykiri_ui.py shells/saha.js || {
    echo "❌ geri alindi"; cp shells/saha.js.bak_aykiri shells/saha.js; exit 1; }
  SONRA=$(wc -c < shells/saha.js)
  echo "  boyut: $ONCE -> $SONRA"
  [ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp shells/saha.js.bak_aykiri shells/saha.js; exit 1; }
  node --check shells/saha.js || { echo "❌ NODE FAIL"; cp shells/saha.js.bak_aykiri shells/saha.js; exit 1; }
  echo "  NODE_OK"
  # ⚠ closure tuzagi — _aykiriGoster onclick'ten cagriliyor, GLOBAL olmali
  grep -q "^function _aykiriGoster" shells/saha.js && echo "  ✅ _aykiriGoster sutun 0 (global)" || {
    echo "  ❌ _aykiriGoster GLOBAL DEGIL — onclick calismaz"; cp shells/saha.js.bak_aykiri shells/saha.js; exit 1; }
fi

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/saha.js krb-assessment:/app/shells/saha.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET /              -> HTTP %{http_code}\n" http://localhost:8080/
curl -s -o /tmp/_s.js -w "  GET shells/saha.js -> HTTP %{http_code}\n" http://localhost:8080/shells/saha.js
grep -c "_aykiriGoster" /tmp/_s.js | xargs echo "  _aykiriGoster servis ediliyor:"

echo
echo "############ 5) SONUC — ARALIK ARTIK TEMIZ ############"
$PSQL -c "
WITH m AS (
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat) AS med
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat='385/65R22.5' AND upper(marka)='BRIDGESTONE'
     AND grup_adi LIKE 'LASTIK%' AND birim_fiyat>0
     AND fatura_tarihi >= date_trunc('year',CURRENT_DATE))
SELECT 'TEMIZ (aykirilar HARIC)' AS hesap,
       ROUND(MIN(s.birim_fiyat))  AS min_TL,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY s.birim_fiyat)::numeric) AS medyan_TL,
       ROUND(MAX(s.birim_fiyat))  AS max_TL,
       COUNT(*)::int AS satis,
       ROUND((SELECT med*0.30 FROM m)) AS aykiri_esigi_TL
  FROM bi_satis_faturalari s, m
 WHERE s.tenant_id='$TEN' AND s.ebat='385/65R22.5' AND upper(s.marka)='BRIDGESTONE'
   AND s.grup_adi LIKE 'LASTIK%' AND s.birim_fiyat >= m.med*0.30
   AND s.fatura_tarihi >= date_trunc('year',CURRENT_DATE);"

echo "  -- ARALIK DISINDA TUTULANLAR (ekranda 'goster'e tiklayinca bunlar cikacak) --"
$PSQL -c "
WITH m AS (
  SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat) AS med
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat='385/65R22.5' AND upper(marka)='BRIDGESTONE'
     AND grup_adi LIKE 'LASTIK%' AND birim_fiyat>0
     AND fatura_tarihi >= date_trunc('year',CURRENT_DATE))
SELECT s.musteri_adi AS musteri, ROUND(s.birim_fiyat) AS birim_TL, s.miktar AS adet,
       s.fatura_tarihi::date AS tarih, s.fatura_no, s.satis_temsilcisi AS temsilci
  FROM bi_satis_faturalari s, m
 WHERE s.tenant_id='$TEN' AND s.ebat='385/65R22.5' AND upper(s.marka)='BRIDGESTONE'
   AND s.grup_adi LIKE 'LASTIK%' AND s.birim_fiyat > 0 AND s.birim_fiyat < m.med*0.30
   AND s.fatura_tarihi >= date_trunc('year',CURRENT_DATE)
 ORDER BY s.birim_fiyat;"
echo "  ^ SILINMEDILER. Gizlenmediler. Sadece araligi carpitmasinlar diye ayrildilar."

git add -A && git commit -q -m "feat(teklif): AYKIRI_V1 — medyanin %30 altindaki satislar fiyat araligindan cikarildi; kac tane oldugu yaziliyor ve tiklaninca musteri/fiyat/tarih/fatura ile listeleniyor" && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_aykiri server_container.mjs; cp shells/saha.js.bak_aykiri shells/saha.js"
