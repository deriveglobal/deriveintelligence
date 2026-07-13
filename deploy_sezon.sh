#!/usr/bin/env bash
# SEZON_V1 — ikame maliyeti sezon + arac tipine gore.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) SORUN — su an ne oluyor? ############"
echo "  Tesvik tablosunda SADECE sezon='KIS' var:"
$PSQL -c "
SELECT sezon, arac_tipi, count(*) AS satir, string_agg(DISTINCT marka, ', ') AS markalar
  FROM bi_fiyat_iskonto WHERE tenant_id='$TEN'::uuid AND aktif
 GROUP BY 1,2 ORDER BY 1,2;"
echo "  Ama bu yil satislar:"
$PSQL -c "
SELECT CASE WHEN kategori ILIKE '%4 MEVSIM%' THEN '4MEVSIM'
            WHEN kategori ILIKE '%KIS%' THEN 'KIS'
            WHEN kategori ILIKE '%YAZ%' THEN 'YAZ'
            ELSE 'TICARI/DIGER (' || kategori || ')' END AS sezon_grubu,
       count(*) AS satir
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%'
   AND fatura_tarihi >= date_trunc('year',CURRENT_DATE)
 GROUP BY 1 ORDER BY 2 DESC LIMIT 6;"
echo "  ^ YAZ en cok satilan ama tesviki YOK. Sorgu sezona bakmadigi icin"
echo "    YAZ lastigine KIS iskontosu uyguluyordu."

echo
echo "############ 1) YAMA: sunucu ############"
if grep -q "SEZON_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_sezon
  python3 patch_sezon.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_sezon server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_sezon server_container.mjs; exit 1; }
  echo "  NODE_OK"
  grep -q "^function _tesvikAnahtar" server_container.mjs && echo "  ✅ _tesvikAnahtar sutun 0" || {
    echo "  ❌ closure icinde"; cp server_container.mjs.bak_sezon server_container.mjs; exit 1; }
  grep -q "^async function _tesvikBul" server_container.mjs && echo "  ✅ _tesvikBul sutun 0" || {
    echo "  ❌ closure icinde"; cp server_container.mjs.bak_sezon server_container.mjs; exit 1; }
fi

echo
echo "############ 2) SQL'i POSTGRES'E DOGRULAT ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT baz_iskonto1 b1, baz_iskonto2 b2, ds, skala_primi sk, sezon, arac_tipi
  FROM bi_fiyat_iskonto
 WHERE tenant_id='$TEN'::uuid AND upper(marka)=upper('LASSA') AND aktif=true
   AND sezon='KIS' AND arac_tipi='BINEK'
   AND (rim_alt IS NULL OR 16>=rim_alt) AND (rim_ust IS NULL OR 16<=rim_ust)
 ORDER BY rim_alt NULLS LAST LIMIT 1;" >/dev/null \
 && echo "  SQL_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_sezon server_container.mjs; exit 1; }

echo
echo "############ 3) YAMA: ekran ############"
cp shells/saha.js shells/saha.js.bak_sezon
ONCE=$(wc -c < shells/saha.js)
if grep -q "SEZON_UI_V1" shells/saha.js; then echo "  ZATEN YAMALI"; else
  python3 patch_sezon_ui.py shells/saha.js || {
    echo "❌ geri alindi"; cp shells/saha.js.bak_sezon shells/saha.js; exit 1; }
  SONRA=$(wc -c < shells/saha.js)
  echo "  boyut: $ONCE -> $SONRA"
  [ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp shells/saha.js.bak_sezon shells/saha.js; exit 1; }
  node --check shells/saha.js || { echo "❌ NODE FAIL"; cp shells/saha.js.bak_sezon shells/saha.js; exit 1; }
  echo "  NODE_OK"
  grep -q "^function _tesvikHTML" shells/saha.js && echo "  ✅ _tesvikHTML sutun 0" || {
    echo "  ❌ closure icinde"; cp shells/saha.js.bak_sezon shells/saha.js; exit 1; }
fi

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/saha.js krb-assessment:/app/shells/saha.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) DAVRANIS TESTI — hangi urun ne alacak? ############"
$PSQL -c "
WITH ornek AS (
  SELECT DISTINCT ON (kategori) kategori, marka, ebat, grup_adi
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND ebat <> ''
     AND fatura_tarihi >= date_trunc('year',CURRENT_DATE)
   ORDER BY kategori, fatura_tarihi DESC)
SELECT o.kategori, o.marka, o.ebat,
       CASE WHEN o.kategori ILIKE '%4 MEVSIM%' THEN '4MEVSIM'
            WHEN o.kategori ILIKE '%KIS%' THEN 'KIS'
            WHEN o.kategori ILIKE '%YAZ%' THEN 'YAZ' ELSE 'TUM' END AS aranan_sezon,
       CASE WHEN o.kategori ILIKE '%TBR%' OR o.grup_adi ILIKE '%TICARI%' THEN 'KAMYON'
            WHEN o.kategori ILIKE '%OTR%' THEN 'IS_MAKINESI'
            WHEN o.kategori ILIKE '%LSR%' THEN 'HAFIF_TICARI'
            ELSE 'BINEK' END AS aranan_arac,
       CASE WHEN EXISTS (
              SELECT 1 FROM bi_fiyat_iskonto i
               WHERE i.tenant_id='$TEN'::uuid AND upper(i.marka)=upper(o.marka) AND i.aktif)
            THEN 'marka var' ELSE '❌ MARKA YOK' END AS marka_durumu
  FROM ornek o ORDER BY 1 LIMIT 8;"
echo "  ^ Eslesme yoksa ekranda: '⚠ Bu urun icin tesvik tanimli degil' yazacak."
echo "    YANLIS bir marj GOSTERILMEYECEK."

echo
echo "############ 6) ⚠ KRB YAZ/TBR TESVIGINI YUKLEYINCE ############"
echo "  Kod DEGISMEYECEK. Tablo dolunca hesaplama KENDILIGINDEN baslar."
echo "  Yukleme: POST /api/price-list/discount-tiers  (BI kabugundaki Fiyat/Iskonto ekrani)"

git add -A && git commit -q -m "fix(teklif): SEZON_V1 — ikame maliyeti sezon+arac tipine gore hesaplaniyor; eslesme yoksa YANLIS marj yerine 'tesvik tanimli degil' deniyor; yaz/TBR tesviki yuklenince kendiliginden devreye girer" && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_sezon server_container.mjs; cp shells/saha.js.bak_sezon shells/saha.js"
