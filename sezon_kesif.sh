#!/usr/bin/env bash
# Salt okuma. IKAME maliyeti (liste - tesvik) SEZONU dikkate aliyor mu?
# Suphe: bi_fiyat_iskonto'da sezon/arac_tipi VAR ama sorgu bunlari KULLANMIYOR.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
S=/opt/krb-assessment/server_container.mjs

echo "############ 1) bi_fiyat_iskonto — SEMA ############"
$PSQL -c "\d bi_fiyat_iskonto"

echo
echo "############ 2) ICINDE NE VAR? ############"
$PSQL -c "
SELECT marka, arac_tipi, sezon, rim_alt, rim_ust,
       baz_iskonto1 b1, baz_iskonto2 b2, ds, skala_primi sk, aktif
  FROM bi_fiyat_iskonto WHERE tenant_id='$TEN'::uuid
 ORDER BY marka, arac_tipi, sezon, rim_alt NULLS FIRST;"

echo
echo "############ 3) ⚠ AYNI MARKA+RIM icin KAC SATIR var? ############"
echo "   (>1 ise: sorgu LIMIT 1 ile RASTGELE birini aliyor demektir)"
$PSQL -c "
SELECT marka, COALESCE(rim_alt::text,'-') AS rim_alt,
       count(*) AS satir,
       string_agg(DISTINCT COALESCE(sezon,'(bos)'), ' | ')     AS sezonlar,
       string_agg(DISTINCT COALESCE(arac_tipi,'(bos)'), ' | ') AS arac_tipleri,
       string_agg(DISTINCT baz_iskonto1::text, ' | ')          AS farkli_iskontolar
  FROM bi_fiyat_iskonto WHERE tenant_id='$TEN'::uuid AND aktif
 GROUP BY 1,2 HAVING count(*) > 1
 ORDER BY 3 DESC;"
echo "   ^ BOS ise sorun yok. SATIR VARSA: yanlis sezonun iskontosu uygulaniyor olabilir."

echo
echo "############ 4) SORGU sezonu kullaniyor mu? (kod) ############"
grep -n "bi_fiyat_iskonto" $S | head -5
echo "   -- sorgunun tam hali --"
grep -n "baz_iskonto1 b1" $S | head -2
sed -n "$(grep -n 'baz_iskonto1 b1' $S | head -1 | cut -d: -f1)p" $S | fold -w 150

echo
echo "############ 5) FIYAT LISTESI'nde sezon var mi? ############"
$PSQL -c "\d bi_fiyat_listesi_kalemler" | sed -n '1,20p'
$PSQL -c "\d bi_fiyat_listesi_uploads" | sed -n '1,18p'

echo
echo "############ 6) ⚠ KIS ve YAZ ayni ebatta FARKLI liste fiyati mi? ############"
$PSQL -c "
SELECT u.marka, u.sezon, count(*) AS kalem,
       round(avg(k.liste_fiyati)) AS ort_liste_TL,
       min(k.liste_fiyati)::int AS min_TL, max(k.liste_fiyati)::int AS max_TL
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id = k.upload_id
 WHERE k.tenant_id='$TEN'::uuid AND u.aktif AND k.liste_fiyati > 0
 GROUP BY 1,2 ORDER BY 1,2;" 2>/dev/null || echo "  (sezon kolonu yok olabilir)"

echo
echo "############ 7) SATISTA sezon dagilimi (kategori) ############"
$PSQL -c "
SELECT kategori, count(*) AS satir, round(avg(birim_fiyat)) AS ort_fiyat
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND birim_fiyat>0
   AND fatura_tarihi >= date_trunc('year',CURRENT_DATE)
 GROUP BY 1 ORDER BY 2 DESC LIMIT 8;"
echo "   ^ KIS / YAZ / 4 MEVSIM / TBR ... — iskonto bunlara gore DEGISIYOR mu?"
