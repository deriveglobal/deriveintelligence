#!/usr/bin/env bash
# BRUT_V1 — iki is:
#   1) 26 bozuk birim_fiyat satirini onar (birim x miktar <> satir_tutar)
#   2) Ekranda BRUT maliyeti acikca etiketle (prim harictir; marj ALT SINIR)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ 26 BOZUK birim_fiyat — once GOR ############"
echo "   Kanit: kalem 584010 (12.00R24 BRIDGESTONE)"
echo "     alis  : 59.253 TL x 15 adet = 888.791"
echo "     satis : ciro 897.435 / 15 adet = 59.829 TL  -> marj +%1 (SAGLIKLI)"
echo "     AMA birim_fiyat kolonu '1.128' diyor -> ekranda -%5.151 marj gorunuyordu."
$PSQL -c "
SELECT id, kalem_kodu, left(kalem_tanimi,28) AS kalem, ebat,
       miktar, birim_fiyat AS bozuk_birim,
       round(satir_tutar/NULLIF(miktar,0),2) AS dogru_birim,
       satir_tutar, fatura_tarihi
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
   AND abs(birim_fiyat*miktar - satir_tutar) > 0.02*abs(satir_tutar)
 ORDER BY abs(satir_tutar) DESC LIMIT 30;"

TOPLAM=$($PSQL -tA -c "
SELECT count(*) FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
   AND abs(birim_fiyat*miktar - satir_tutar) > 0.02*abs(satir_tutar);")
echo "  TOPLAM BOZUK SATIR: $TOPLAM"

if [ "${1:-}" != "--yaz" ]; then
  echo
  echo "  KURU CALISMA — hicbir sey degismedi."
  echo "  Onarmak ve ekrani yamalamak icin:  ./deploy_brut.sh --yaz"
  exit 0
fi

echo
echo "############ 2) ONAR — birim_fiyat = satir_tutar / miktar ############"
DAMGA=$(date +%Y%m%d_%H%M%S)
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
CREATE TABLE bi_satis_birimfiyat_yedek_${DAMGA} AS
  SELECT id, birim_fiyat AS eski_birim_fiyat, miktar, satir_tutar, now() AS yedek_zamani
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
     AND abs(birim_fiyat*miktar - satir_tutar) > 0.02*abs(satir_tutar);

UPDATE bi_satis_faturalari
   SET birim_fiyat = round(satir_tutar / miktar, 4)
 WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
   AND abs(birim_fiyat*miktar - satir_tutar) > 0.02*abs(satir_tutar);

DO \$\$
DECLARE kalan int;
BEGIN
  SELECT count(*) INTO kalan FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
     AND abs(birim_fiyat*miktar - satir_tutar) > 0.02*abs(satir_tutar);
  IF kalan > 0 THEN RAISE EXCEPTION 'RED: % satir hala bozuk', kalan; END IF;
  RAISE NOTICE '✅ tum satirlar tutarli';
END \$\$;
COMMIT;
SQL
echo "  yedek: bi_satis_birimfiyat_yedek_${DAMGA}"

echo
echo "   -- 584010 simdi ne diyor? --"
$PSQL -c "
SELECT kalem_kodu, ebat, miktar, birim_fiyat, satir_tutar
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND kalem_kodu='584010'
 ORDER BY fatura_tarihi DESC LIMIT 3;"

echo
echo "############ 3) YAMA: ekran — BRUT maliyet etiketi ############"
if grep -q "BRÜT maliyet" shells/saha.js; then echo "  ZATEN YAMALI"; else
  cp shells/saha.js shells/saha.js.bak_brut
  ONCE=$(wc -c < shells/saha.js)
  python3 patch_brut_ui.py shells/saha.js || {
    echo "❌ geri alindi"; cp shells/saha.js.bak_brut shells/saha.js; exit 1; }
  SONRA=$(wc -c < shells/saha.js)
  echo "  boyut: $ONCE -> $SONRA"
  [ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp shells/saha.js.bak_brut shells/saha.js; exit 1; }
  node --check shells/saha.js || { echo "❌ NODE FAIL"; cp shells/saha.js.bak_brut shells/saha.js; exit 1; }
  echo "  NODE_OK"
  grep -q "^function _tesvikHTML" shells/saha.js && echo "  ✅ _tesvikHTML sutun 0" || {
    echo "  ❌ closure icinde"; cp shells/saha.js.bak_brut shells/saha.js; exit 1; }
  grep -q "teşvikleri zaten içinde taşır" shells/saha.js \
    && { echo "  ❌ YANLIS CUMLE HALA VAR"; cp shells/saha.js.bak_brut shells/saha.js; exit 1; } \
    || echo "  ✅ yanlis cumle silindi"
fi

echo
echo "############ 4) DAGIT ############"
docker cp shells/saha.js krb-assessment:/app/shells/saha.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) ONARIM SONRASI — marj dagilimi degisti mi? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
m AS (
  SELECT f.satir_tutar,
         EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(f.marka)) AS bayilik,
         100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0) AS marj
    FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 60)
SELECT CASE WHEN bayilik THEN '🅑 BAYILIK (BRUT maliyet — prim haric)' ELSE '🅝 NET ALIM (gercek maliyet)' END AS sinif,
       count(*) AS satir,
       round(avg(marj)) AS ort_marj_pct,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY marj)::numeric) AS medyan_marj_pct
  FROM m GROUP BY 1 ORDER BY 1;"
echo "  ^ BAYILIK ort_marj artik -244 DEGIL (12.00R2 onarildi)."
echo "    Bu marj hala BRUT — prim (33,5M) dusulmemis. GERCEK MARJIN ALT SINIRI."

echo
echo "############ 6) ⚠ KRB'NIN YUKLEMESI GEREKEN 10 TESVIK SATIRI ############"
$PSQL -c "
SELECT s.marka,
       CASE WHEN s.kategori ILIKE '%4 MEVSIM%' THEN '4MEVSIM'
            WHEN s.kategori ILIKE '%YAZ%' THEN 'YAZ' ELSE 'TICARI/TBR' END AS eksik_sezon,
       count(*) AS satir, round(sum(s.satir_tutar)/1e6,1) AS ciro_MTL
  FROM bi_satis_faturalari s
 WHERE s.tenant_id='$TEN' AND s.grup_adi LIKE 'LASTIK%'
   AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   AND s.kategori NOT ILIKE '%KIS%'
   AND EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                WHERE i.tenant_id='$TEN'::uuid AND i.aktif AND upper(i.marka)=upper(s.marka))
 GROUP BY 1,2 ORDER BY 4 DESC;"
echo "  ^ Bunlar yuklenince ekran BRUT'tan NET maliyete gecer, uyari kalkar."

git add -A && git commit -q -m "fix(teklif): BRUT_V1 — 26 bozuk birim_fiyat onarildi (birim=satir_tutar/miktar). Ekran artik bayilik maliyetini BRUT diye etiketliyor: Brisa/Conti primi ayri fatura ediliyor (33,5M/yil), fatura fiyati nihai maliyet DEGIL, gosterilen marj gercek marjin ALT SINIRI. 'Tesvik zaten fatura fiyatinin icinde' iddiasi YANLISTI, geri alindi." && echo "  COMMITTED"

echo
echo "✅ Geri alma:"
echo "   cp shells/saha.js.bak_brut shells/saha.js && docker cp shells/saha.js krb-assessment:/app/shells/saha.js && docker restart krb-assessment"
echo "   UPDATE bi_satis_faturalari f SET birim_fiyat = y.eski_birim_fiyat"
echo "     FROM bi_satis_birimfiyat_yedek_${DAMGA} y WHERE y.id = f.id;"
