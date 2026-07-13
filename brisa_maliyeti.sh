#!/usr/bin/env bash
# ⚠ SORU: Brisa bayiligini birakmak KRB'ye NEYE MAL OLDU?
#
# Uc bilesen, ucu de OLCULEBILIR:
#   1) HACIM kaybi   — satilamayan lastik (ikame markalar acigi kapatamadi)
#   2) MARJ kaybi    — bayilik markasi yerine net alim markasi satmanin farki
#   3) PRIM kaybi    — bayi olmayinca prim hakedisi YOK (2026'da 33,5M)
#
# ⚠ ENFLASYON TUZAGI: TL ciro 4 yilda 4x artti. CIRO ile kiyaslamak YANILTIR.
#   ADET ile olcup, BUGUNKU fiyatla degerlemek gerekir.
#
# ⚠ KARSI-OLGU (counterfactual) bir TAHMINDIR. Varsayimi ACIKCA yaziyorum.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) TOPLAM LASTIK HACMI — yil yil (ADET, enflasyondan bagimsiz) ############"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
       round(sum(miktar)) AS toplam_adet,
       round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(sum(satir_tutar)/NULLIF(sum(miktar),0)) AS ort_birim_TL,
       round(sum(miktar) FILTER (WHERE upper(marka) IN ('LASSA','BRIDGESTONE','DAYTON'))) AS brisa_adet,
       round(100.0*sum(miktar) FILTER (WHERE upper(marka) IN ('LASSA','BRIDGESTONE','DAYTON'))
             /NULLIF(sum(miktar),0)) AS brisa_pay_pct
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
 GROUP BY 1 ORDER BY 1;"
echo "  ^ ⚠ 2026 kismi yil (Tem'e kadar). ort_birim_TL enflasyonu gosterir."
echo "    ADET dususu = GERCEK kayip. Ciro artisi ENFLASYON, buyume DEGIL."

echo
echo "############ 1b) ⚠⚠ SEGMENT KORELASYONU — sadece KIS mi dustu, HEPSI mi? ############"
echo "   Bayilik kopunca musteri SADECE kis lastigi icin gitmez."
echo "   Tum ihtiyacini baska yere tasir. Eger YAZ ve TBR de dustuyse,"
echo "   kayip kategori kaybi DEGIL — MUSTERI kaybidir. Cok daha buyuk."
$PSQL -c "
SELECT CASE WHEN kategori ILIKE '%4 MEVSIM%' THEN '4MEVSIM'
            WHEN kategori ILIKE '%KIS%' THEN 'KIS'
            WHEN kategori ILIKE '%YAZ%' THEN 'YAZ'
            WHEN kategori ILIKE '%TBR%' THEN 'TBR'
            WHEN kategori ILIKE '%OTR%' OR kategori ILIKE '%IND%' THEN 'OTR/IND'
            ELSE 'DIGER' END AS segment,
       round(sum(miktar) FILTER (WHERE EXTRACT(YEAR FROM fatura_tarihi)=2022)) AS y2022,
       round(sum(miktar) FILTER (WHERE EXTRACT(YEAR FROM fatura_tarihi)=2023)) AS y2023,
       round(sum(miktar) FILTER (WHERE EXTRACT(YEAR FROM fatura_tarihi)=2024)) AS y2024,
       round(sum(miktar) FILTER (WHERE EXTRACT(YEAR FROM fatura_tarihi)=2025)) AS y2025,
       round(100.0*sum(miktar) FILTER (WHERE EXTRACT(YEAR FROM fatura_tarihi)=2025)
             /NULLIF(sum(miktar) FILTER (WHERE EXTRACT(YEAR FROM fatura_tarihi)=2022),0)) AS y25_vs_y22_pct
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
 GROUP BY 1 ORDER BY 2 DESC NULLS LAST;"
echo "  ^ y25_vs_y22_pct: 100 = degismedi. 50 = YARIYA dustu."
echo "    ⚠ SADECE KIS dustuyse -> kategori kaybi, telafi edilebilir."
echo "       YAZ ve TBR de dustuyse -> MUSTERI KAYBI. Brisa musteriyi goturmus."
echo "       TBR Brisa'nin gucli oldugu segment DEGIL — orasi da dustuyse"
echo "       musteri KRB'den TAMAMEN kopmus demektir."

echo
echo "############ 1c) MUSTERI SAYISI — kac musteri kayboldu? ############"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
       count(DISTINCT musteri_kodu) AS aktif_musteri,
       count(DISTINCT musteri_kodu) FILTER (WHERE kategori ILIKE '%KIS%') AS kis_alan_musteri,
       round(sum(miktar)) AS adet
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
 GROUP BY 1 ORDER BY 1;"
echo "  ^ Musteri sayisi da dustuyse: kayip GECICI degil, YAPISAL."

echo
echo "############ 2) ⚠ KARSI-OLGU — Brisa devam etseydi ne olurdu? ############"
echo "   VARSAYIM: 2022'deki toplam adet (bayili yil) korunurdu."
echo "   Bu MUHAFAZAKAR: pazar buyumesi/enflasyon-ustu artis SAYILMIYOR."
$PSQL -c "
WITH y AS (
  SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
         sum(miktar) AS adet,
         sum(satir_tutar)/NULLIF(sum(miktar),0) AS birim
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
     AND fatura_tarihi >= DATE '2022-01-01' AND fatura_tarihi < DATE '2026-01-01'
   GROUP BY 1),
baz AS (SELECT adet AS baz_adet FROM y WHERE yil = 2022)
SELECT y.yil, round(y.adet) AS gerceklesen_adet,
       round(b.baz_adet) AS karsi_olgu_adet,
       round(b.baz_adet - y.adet) AS KAYIP_ADET,
       round(y.birim) AS o_yilki_birim_TL,
       round((b.baz_adet - y.adet) * y.birim / 1e6, 1) AS KAYIP_CIRO_MTL
  FROM y CROSS JOIN baz b WHERE y.yil >= 2023 ORDER BY 1;"
echo "  ^ KAYIP_CIRO o yilin KENDI fiyatiyla — enflasyon dogru yansiyor."

echo
echo "############ 3) MARJ FARKI — bayilik vs net alim (bugunku olcum) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
mm AS (
  SELECT EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(f.marka)) AS bayilik,
         100.0*(f.birim_fiyat - son.m)/NULLIF(f.birim_fiyat,0) AS marj
    FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu=f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat>0 AND f.miktar>0
     AND f.fatura_tarihi >= CURRENT_DATE - 60
     AND 100.0*(f.birim_fiyat - son.m)/NULLIF(f.birim_fiyat,0) BETWEEN -50 AND 90)
SELECT CASE WHEN bayilik THEN '🅑 BAYILIK (BRUT — prim HARIC)' ELSE '🅝 NET ALIM (gercek)' END AS sinif,
       count(*) AS satir,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY marj)::numeric) AS medyan_marj
  FROM mm GROUP BY 1;"
echo "  ⚠ BAYILIK marji BRUT — prim (33,5M/yil) dusulmemis. GERCEK bayilik marji DAHA YUKSEK."
echo "    Net alim marji ise GERCEK (prim yok). Yani gercek fark, gorunenden BUYUK."

echo
echo "############ 4) ⚠ PRIM KAYBI — bayi degilken prim hakedisi SIFIR ############"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
       count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS prim_hakedisi_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN'
   AND (grup_adi ILIKE '%PRIM%' OR grup_adi ILIKE '%PRİM%'
        OR marka ILIKE '%PRIM%' OR marka ILIKE '%PRİM%')
 GROUP BY 1 ORDER BY 1;"
echo "  ^ 2026'da 33,5M. Bayisiz yillarda ne kadardi? Fark = PRIM KAYBI."

echo
echo "############ 5) 💀 OLU STOK — bayilikten kalan mal hala rafta mi? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT s.marka, s.sezon, count(*) AS sku, round(sum(s.adet)) AS adet,
       round(sum(s.adet*son.m)/1e6,2) AS bagli_para_MTL,
       (SELECT max(f.fatura_tarihi) FROM bi_satis_faturalari f
         WHERE f.tenant_id='$TEN' AND upper(f.marka)=upper(s.marka) AND f.miktar>0) AS son_satis
  FROM bi_stok_anlik s JOIN son ON son.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet > 0
   AND upper(s.marka) IN ('BRIDGESTONE','LASSA','DAYTON')
   AND NOT EXISTS (SELECT 1 FROM bi_satis_faturalari f
                    WHERE f.tenant_id='$TEN' AND f.kalem_kodu=s.kalem_kodu
                      AND f.fatura_tarihi >= CURRENT_DATE - 365 AND f.miktar>0)
 GROUP BY 1,2 ORDER BY 5 DESC;"
echo "  ^ Brisa markali, 1 yildir SATILMAMIS stok. Eski bayilikten kalmis olabilir."
