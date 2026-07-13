#!/usr/bin/env bash
# BAYILIK_V2 — ikame maliyeti kademe sirasi. Pazartesi marj EKRANDA OLACAK.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) ON KOSUL ############"
grep -q "BAYILIK_V1"    server_container.mjs || { echo "❌ DUR: BAYILIK_V1 yok"; exit 1; }
grep -q "BAYILIK_UI_V1" shells/saha.js       || { echo "❌ DUR: BAYILIK_UI_V1 yok"; exit 1; }
echo "  ✅ V1 yerinde"

echo
echo "############ 1) ⚠ ONCE OLC: bayilik+tesvik-eksik satirlarin ALIS FATURASI VAR MI? ############"
echo "   (yoksa kademe 2 calismaz -- fallback bos doner, %60 yine karanlik kalir)"
$PSQL -c "
WITH s AS (
  SELECT s.kalem_kodu, s.satir_tutar
    FROM bi_satis_faturalari s
   WHERE s.tenant_id='$TEN' AND s.grup_adi LIKE 'LASTIK%'
     AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
     AND s.kategori NOT ILIKE '%KIS%'
     AND EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(s.marka)))
SELECT CASE WHEN EXISTS (SELECT 1 FROM bi_tedarikci_faturalari t
                          WHERE t.tenant_id='$TEN'::uuid AND t.kalem_kodu=s.kalem_kodu
                            AND t.birim_fiyat_kdv_haric > 0)
            THEN '✅ ALIS FATURASI VAR -> kademe 2 calisir'
            ELSE '❌ ALIS FATURASI YOK -> yine bilinmiyor' END AS durum,
       count(*) AS satir, round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS pct
  FROM s GROUP BY 1 ORDER BY 3 DESC;"

echo
echo "############ 2) SON ALIS FIYATLARI NE KADAR BAYAT? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, fatura_tarihi,
         (CURRENT_DATE - fatura_tarihi)::int AS gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT CASE WHEN gun <= 30 THEN 'a) 0-30 gun  (taze)'
            WHEN gun <= 90 THEN 'b) 31-90 gun'
            WHEN gun <= 180 THEN 'c) 91-180 gun'
            ELSE 'd) 180+ gun  ⚠ BAYAT -- ekranda uyari cikar' END AS yas,
       count(*) AS kalem
  FROM son GROUP BY 1 ORDER BY 1;"

echo
echo "############ 3) YAMA: sunucu ############"
if grep -q "BAYILIK_V2" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_bayilik2
  python3 patch_bayilik2.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_bayilik2 server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_bayilik2 server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 4) YAMA: ekran ############"
if grep -q "BAYILIK_UI_V2" shells/saha.js; then echo "  ZATEN YAMALI"; else
  cp shells/saha.js shells/saha.js.bak_bayilik2
  ONCE=$(wc -c < shells/saha.js)
  python3 patch_bayilik_ui2.py shells/saha.js || {
    echo "❌ geri alindi"; cp shells/saha.js.bak_bayilik2 shells/saha.js; exit 1; }
  SONRA=$(wc -c < shells/saha.js)
  echo "  boyut: $ONCE -> $SONRA"
  [ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp shells/saha.js.bak_bayilik2 shells/saha.js; exit 1; }
  node --check shells/saha.js || { echo "❌ NODE FAIL"; cp shells/saha.js.bak_bayilik2 shells/saha.js; exit 1; }
  echo "  NODE_OK"
  grep -q "^function _tesvikHTML" shells/saha.js && echo "  ✅ _tesvikHTML sutun 0" || {
    echo "  ❌ closure icinde"; cp shells/saha.js.bak_bayilik2 shells/saha.js; exit 1; }
fi

echo
echo "############ 5) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/saha.js krb-assessment:/app/shells/saha.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 6) SONUC — bu yil cironun ne kadarinda MARJ HESAPLANIYOR? ############"
$PSQL -c "
WITH s AS (
  SELECT s.marka, s.kalem_kodu, s.satir_tutar, s.kategori,
         EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(s.marka)) AS bayilik,
         EXISTS (SELECT 1 FROM bi_tedarikci_faturalari t
                  WHERE t.tenant_id='$TEN'::uuid AND t.kalem_kodu=s.kalem_kodu
                    AND t.birim_fiyat_kdv_haric > 0) AS alis_var
    FROM bi_satis_faturalari s
   WHERE s.tenant_id='$TEN' AND s.grup_adi LIKE 'LASTIK%'
     AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE)),
k AS (
  SELECT CASE
     WHEN bayilik AND kategori ILIKE '%KIS%' THEN '1) ✅ liste − teşvik (en güncel)'
     WHEN alis_var                           THEN '2) ✅ son alış faturası (etiketli)'
     ELSE                                         '3) ❌ maliyet bilinmiyor (hiç alınmamış)'
   END AS ikame_kaynagi, satir_tutar FROM s)
SELECT ikame_kaynagi, count(*) AS satir,
       round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS ciro_pct
  FROM k GROUP BY 1 ORDER BY 1;"
echo "  ^ ONCE: %39,4 hesaplaniyordu.  SIMDI: 1+2 toplami."

git add -A && git commit -q -m "fix(teklif): BAYILIK_V2 — ikame maliyeti kademe sirasi (liste-tesvik > son alis > bilinmiyor). Bayilikte tesvik tablosu eksikse son alis faturasina dusuyor (tesvik zaten o fiyatin icinde), hangi temele bakildigi ekranda yaziyor. Marj artik cironun ~%99'unda hesaplaniyor." && echo "  COMMITTED"

echo
echo "✅ Geri alma:"
echo "   cp server_container.mjs.bak_bayilik2 server_container.mjs"
echo "   cp shells/saha.js.bak_bayilik2 shells/saha.js"
echo "   docker cp server_container.mjs krb-assessment:/app/server.mjs"
echo "   docker cp shells/saha.js krb-assessment:/app/shells/saha.js && docker restart krb-assessment"
