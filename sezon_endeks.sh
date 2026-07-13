#!/usr/bin/env bash
# Salt okuma. SEZON DESENI GERCEKTEN VAR MI? Model kurmadan ONCE OLC.
#
# FATIH: "ebat ebat en verimli stok seviyesi tahmin edilebilir, ama sezon
#         etkisi hesaba katilmali"
#
# ⚠ Ortalama aylik talebe gore stok tutarsan:
#     KISIN elin BOS kalir (kacan satis), YAZIN depo DOLU bekler (bagli para).
#   Ayni hatanin iki yonu. Stok gunu 146 -> yillik finansman 72,2M TL.
#
# ONCE DESENI KANITLA, SONRA MODEL KUR. Sirasi bu.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ SEZON ENDEKSI — 6 yillik gercek satis (adet) ############"
echo "   endeks 100 = o kategorinin ORTALAMA ayi. 200 = iki kati."
$PSQL -c "
WITH aylik AS (
  SELECT CASE WHEN kategori ILIKE '%4 MEVSIM%' THEN '4MEVSIM'
              WHEN kategori ILIKE '%KIS%' THEN 'KIS'
              WHEN kategori ILIKE '%YAZ%' THEN 'YAZ'
              WHEN kategori ILIKE '%TBR%' THEN 'TBR'
              ELSE 'DIGER' END AS kat,
         EXTRACT(MONTH FROM fatura_tarihi)::int AS ay,
         EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
         SUM(miktar) AS adet
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
     AND fatura_tarihi >= DATE '2021-10-01'
   GROUP BY 1,2,3),
ort AS (
  SELECT kat, ay, AVG(adet) AS ay_ort FROM aylik GROUP BY 1,2),
baz AS (
  SELECT kat, AVG(ay_ort) AS genel FROM ort GROUP BY 1)
SELECT o.kat,
       max(CASE WHEN ay=1  THEN round(100*o.ay_ort/b.genel) END) AS oca,
       max(CASE WHEN ay=2  THEN round(100*o.ay_ort/b.genel) END) AS sub,
       max(CASE WHEN ay=3  THEN round(100*o.ay_ort/b.genel) END) AS mar,
       max(CASE WHEN ay=4  THEN round(100*o.ay_ort/b.genel) END) AS nis,
       max(CASE WHEN ay=5  THEN round(100*o.ay_ort/b.genel) END) AS may,
       max(CASE WHEN ay=6  THEN round(100*o.ay_ort/b.genel) END) AS haz,
       max(CASE WHEN ay=7  THEN round(100*o.ay_ort/b.genel) END) AS tem,
       max(CASE WHEN ay=8  THEN round(100*o.ay_ort/b.genel) END) AS agu,
       max(CASE WHEN ay=9  THEN round(100*o.ay_ort/b.genel) END) AS eyl,
       max(CASE WHEN ay=10 THEN round(100*o.ay_ort/b.genel) END) AS eki,
       max(CASE WHEN ay=11 THEN round(100*o.ay_ort/b.genel) END) AS kas,
       max(CASE WHEN ay=12 THEN round(100*o.ay_ort/b.genel) END) AS ara
  FROM ort o JOIN baz b ON b.kat=o.kat
 GROUP BY 1 ORDER BY 1;"
echo "  ^ KIS'ta Eki-Ara yuksek, YAZ'da Nis-Haz yuksekse DESEN GERCEK."
echo "    Duz cikarsa sezon etkisi YOK demektir — o zaman modele KOYMAYIZ."

echo
echo "############ 2) ⚠ DESEN NE KADAR GUVENILIR? — yillar arasi tutarlilik ############"
echo "   Ayni ay her yil benzer mi, yoksa rastgele mi? (varyasyon katsayisi)"
$PSQL -c "
WITH aylik AS (
  SELECT CASE WHEN kategori ILIKE '%KIS%' THEN 'KIS'
              WHEN kategori ILIKE '%YAZ%' THEN 'YAZ'
              WHEN kategori ILIKE '%TBR%' THEN 'TBR' ELSE 'DIGER' END AS kat,
         EXTRACT(MONTH FROM fatura_tarihi)::int AS ay,
         EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
         SUM(miktar) AS adet
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
     AND fatura_tarihi >= DATE '2022-01-01' AND fatura_tarihi < DATE '2026-01-01'
   GROUP BY 1,2,3)
SELECT kat, ay, count(*) AS yil_sayisi,
       round(avg(adet)) AS ort_adet,
       round(stddev(adet)) AS sapma,
       round(100*stddev(adet)/NULLIF(avg(adet),0)) AS varyasyon_pct
  FROM aylik WHERE kat IN ('KIS','YAZ')
 GROUP BY 1,2 ORDER BY 1, 2;"
echo "  ^ varyasyon %50'nin ALTINDAYSA desen tutarli -> tahmin edilebilir."
echo "    USTUNDEYSE o ay rastgele -> guvenlik stogu YUKSEK tutulmali."

echo
echo "############ 3) ⚠ SU AN STOK, SEZONA GORE DOGRU MU? (Temmuz'dayiz) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok AS (
  SELECT s.sezon, SUM(s.adet) AS adet, SUM(s.adet*son.m) AS deger
    FROM bi_stok_anlik s JOIN son ON son.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid GROUP BY 1),
satis AS (   -- son 90 gunun (Nis-Tem) gercek talebi
  SELECT CASE WHEN kategori ILIKE '%4 MEVSIM%' THEN '4 MEVSIM'
              WHEN kategori ILIKE '%KIS%' THEN 'KIS'
              WHEN kategori ILIKE '%YAZ%' THEN 'YAZ'
              WHEN kategori ILIKE '%TBR%' THEN 'TBR' ELSE kategori END AS sezon,
         SUM(miktar)/90.0 AS gunluk_adet
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND fatura_tarihi >= CURRENT_DATE - 90
   GROUP BY 1)
SELECT st.sezon, round(st.adet) AS stok_adet,
       round(st.deger/1e6,1) AS stok_MTL,
       round(sa.gunluk_adet,1) AS gunluk_satis,
       round(st.adet/NULLIF(sa.gunluk_adet,0)) AS KAC_GUNLUK_STOK
  FROM stok st LEFT JOIN satis sa ON upper(sa.sezon)=upper(st.sezon)
 ORDER BY 3 DESC;"
echo "  ^ ⚠ TEMMUZ'dayiz. KIS lastiginde 300+ gunluk stok NORMAL olabilir"
echo "    (sezon geliyor). AMA YAZ lastiginde 300 gunluk stok FELAKETTIR."
echo "    Iste tam da bu yuzden sezon etkisi modele girmeli."
