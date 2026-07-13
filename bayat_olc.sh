#!/usr/bin/env bash
# Salt okuma. IKAME MALIYETI artik cogunlukla SON ALIS FIYATI.
# SORU: o fiyat NE KADAR BAYAT -- ve bayatlik marji ne kadar SISIRIYOR?
# ⚠ 15.022 kalemin son alisi 180+ gun. Ama bunlar bu yil SATILAN kalemler mi?
#   Onemli olan CIRO agirlikli bayatlik, kalem sayisi degil.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ CIRO AGIRLIKLI BAYATLIK (asil soru) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu,
         (CURRENT_DATE - fatura_tarihi)::int AS gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
s AS (
  SELECT f.satir_tutar, son.gun
    FROM bi_satis_faturalari f
    JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%'
     AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE))
SELECT CASE WHEN gun <=  30 THEN 'a) 0-30 gun   ✅ taze'
            WHEN gun <=  90 THEN 'b) 31-90 gun  ✅ kabul edilebilir'
            WHEN gun <= 180 THEN 'c) 91-180 gun ⚠ temkinli'
            ELSE                 'd) 180+ gun   ❌ BAYAT — marj sisirir' END AS yas,
       count(*) AS satis_satiri,
       round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS ciro_pct
  FROM s GROUP BY 1 ORDER BY 1;"
echo "  ^ KALEM sayisi degil CIRO onemli. 15.022 bayat kalemin cogu"
echo "    muhtemelen artik SATILMAYAN olu stok. Gercek risk burada gorunur."

echo
echo "############ 2) ⚠⚠ BAYATLIK MARJI NE KADAR SISIRIYOR? ############"
echo "   Ayni kalemi 180+ gun once VE son 90 gunde almisiz -> fiyat farki?"
$PSQL -c "
WITH eski AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS f_eski, fatura_tarihi AS t_eski
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
     AND fatura_tarihi < CURRENT_DATE - 180
   ORDER BY kalem_kodu, fatura_tarihi DESC),
yeni AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS f_yeni, fatura_tarihi AS t_yeni
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
     AND fatura_tarihi >= CURRENT_DATE - 90
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT count(*) AS ortak_kalem,
       round(avg(100.0*(y.f_yeni - e.f_eski)/NULLIF(e.f_eski,0))::numeric,1) AS ort_zam_pct,
       round(percentile_cont(0.5) WITHIN GROUP (
             ORDER BY 100.0*(y.f_yeni - e.f_eski)/NULLIF(e.f_eski,0))::numeric,1) AS medyan_zam_pct,
       round(avg(y.t_yeni - e.t_eski)) AS ort_gun_farki
  FROM eski e JOIN yeni y ON y.kalem_kodu = e.kalem_kodu;"
echo "  ^ medyan_zam_pct = 180+ gunluk fiyat kullanirsak marj BU KADAR SISER."
echo "    Ornek: gercek marj %8 iken ekranda %8 + zam% gorunur."

echo
echo "############ 3) EN RISKLI SATIRLAR — cok satan + cok bayat ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS f,
         (CURRENT_DATE - fatura_tarihi)::int AS gun, fatura_tarihi
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT f.marka, f.ebat, son.gun AS son_alis_gun_once,
       round(son.f) AS son_alis_TL,
       count(*) AS satis_satiri,
       round(sum(f.satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari f
  JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%'
   AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   AND son.gun > 180
 GROUP BY 1,2,3,4 ORDER BY 6 DESC LIMIT 12;"
echo "  ^ Bunlarda ekran '⚠ bu fiyat N gunluk' uyarisi verecek."

echo
echo "############ 4) ALIS AKISI CANLI MI? — son alis faturasi ne zaman? ############"
$PSQL -c "
SELECT max(fatura_tarihi) AS en_son_alis,
       (CURRENT_DATE - max(fatura_tarihi))::int AS gun_once,
       count(*) FILTER (WHERE fatura_tarihi >= CURRENT_DATE - 30) AS son_30_gun_satir
  FROM bi_tedarikci_faturalari WHERE tenant_id='$TEN'::uuid;"
echo "  ^ ⚠ Alis verisi de manuel yukleniyor. Akis dururssa bayatlik BUYUR."
