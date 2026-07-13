#!/usr/bin/env bash
# Salt okuma. ⚠ UCUNCU BOYUT: "Ekim'de mal bulamayabilirsin" (Fatih)
#
# ON SIPARIS DENKLEMI (kis, binek+hafif ticari, Bridgestone/Lassa):
#   ERKEN ALMANIN MALIYETI  = %7,1
#       Brisa taksit takvimi (SLAYT): Tem/Agu/Eyl faturasi -> 18 Kas + 16 Ara
#                                     Eki/Kas/Ara faturasi -> 22 Oca + 22 Sub
#       Fark = 65 GUN daha erken odeme. %40/yil sermaye -> %7,1
#       ⚠ Odeme tarihleri TAKVIME CAKILI, fatura tarihine bagli DEGIL.
#         Yani Temmuz'da mali alsan bile Kasim'a kadar PARA CIKMIYOR.
#         Stogu Tem-Kas arasi TEDARIKCI finanse ediyor. Tasima maliyeti SIFIR.
#         Tek fark: 65 gun erken odeme.
#   ERKEN ALMANIN GETIRISI  = kesin_siparis_pct (bi_tedarikci_tesvik'te 0.00 — BOS!)
#                           + BULUNABILIRLIK
#   BEKLEMENIN RISKI        = P(bulamama) x kacan satisin marji   <-- BU SCRIPT OLCUYOR
#
# ⚠ Tahmin etmiyoruz. KRB'nin KENDI gecmisi soyluyor.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ KRB GECMISTE NE ZAMAN ALMIS? (kis lastigi) ############"
echo "   Tedarikcide gercekten mal kalmiyorsa, Eki-Ara alimlari KUCUK olmali."
echo "   Cunku denemis, bulamamis. Davranis bunu ele verir."
$PSQL -c "
SELECT EXTRACT(MONTH FROM t.fatura_tarihi)::int AS ay,
       count(*) AS alis_satiri,
       round(sum(t.miktar)) AS adet,
       round(sum(t.satir_kdv_haric)/1e6,1) AS tutar_MTL,
       round(100.0*sum(t.miktar)/SUM(sum(t.miktar)) OVER (),1) AS adet_pct
  FROM bi_tedarikci_faturalari t
 WHERE t.tenant_id='$TEN'::uuid AND t.miktar > 0
   AND t.kategori ILIKE '%KIS%'
   AND t.fatura_tarihi >= DATE '2022-01-01'
 GROUP BY 1 ORDER BY 1;"
echo "  ^ ON SIPARIS PENCERESI Haz-Tem. SEVK Agu-Eyl olabilir."
echo "    Eki-Ara payi DUSUKSE -> gec alim ZOR (Fatih hakli, olculdu)."
echo "    Eki-Ara payi YUKSEKSE -> gec alim MUMKUN, erken alma baskisi ZAYIF."

echo
echo "############ 2) ⚠⚠ KACAN SATIS — zirvede stok tukenen ebatlar ############"
echo "   Bir ebat yil boyu duzenli satarken KAS-ARA'da satisi COKUYORSA,"
echo "   kategori ZIRVEDEYKEN, bu talep dususu DEGIL — STOK YOKLUGUDUR."
$PSQL -c "
WITH kis AS (
  SELECT ebat, marka,
         EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
         EXTRACT(MONTH FROM fatura_tarihi)::int AS ay,
         SUM(miktar) AS adet, SUM(satir_tutar) AS tutar
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
     AND kategori ILIKE '%KIS%' AND ebat <> ''
     AND fatura_tarihi >= DATE '2022-01-01'
   GROUP BY 1,2,3,4),
zirve AS (   -- Kas+Ara: kategorinin en guclu 2 ayi (endeks 270, 381)
  SELECT ebat, marka, yil, SUM(adet) AS zirve_adet, SUM(tutar) AS zirve_tutar
    FROM kis WHERE ay IN (11,12) GROUP BY 1,2,3),
onces AS ( -- Eyl+Eki: sezon basi (endeks 75, 183)
  SELECT ebat, marka, yil, SUM(adet) AS bas_adet
    FROM kis WHERE ay IN (9,10) GROUP BY 1,2,3)
SELECT z.ebat, z.marka, z.yil,
       round(o.bas_adet) AS eyl_eki_adet,
       round(z.zirve_adet) AS kas_ara_adet,
       round(z.zirve_adet / NULLIF(o.bas_adet,0), 2) AS zirve_carpani,
       round(z.zirve_tutar/1e3) AS zirve_ciro_bin_TL
  FROM zirve z JOIN onces o ON o.ebat=z.ebat AND o.marka=z.marka AND o.yil=z.yil
 WHERE o.bas_adet >= 50
   AND z.zirve_adet < o.bas_adet * 0.8     -- zirvede DUSMUS: supheli
 ORDER BY o.bas_adet DESC LIMIT 15;"
echo "  ^ zirve_carpani < 1 ise: sezonun EN GUCLU ayinda satis DUSMUS."
echo "    Talep dusmez — MAL BITMISTIR. Bunlar KACAN SATIS adaylari."
echo "    ⚠ Kesin degil (musteri kaybi da olabilir) ama ON SIPARIS ONCELIGI bunlarda."

echo
echo "############ 3) BU KIS ICIN ELDEKI STOK — sezonu karsiliyor mu? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok AS (
  SELECT s.marka, SUM(s.adet) AS adet, SUM(s.adet*son.m) AS deger
    FROM bi_stok_anlik s JOIN son ON son.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.sezon ILIKE '%KIS%'
   GROUP BY 1),
gecmis AS (   -- gecen kis sezonunda (Eki-Oca) fiilen satilan
  SELECT marka, SUM(miktar) AS sezon_adet
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND kategori ILIKE '%KIS%'
     AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-02-01'
   GROUP BY 1)
SELECT COALESCE(s.marka, g.marka) AS marka,
       round(s.adet) AS eldeki_stok,
       round(g.sezon_adet) AS gecen_sezon_satis,
       round(s.deger/1e6,1) AS stok_MTL,
       round(100.0*s.adet/NULLIF(g.sezon_adet,0)) AS karsilama_pct,
       CASE WHEN s.adet IS NULL THEN '❌ HIC STOK YOK'
            WHEN s.adet < g.sezon_adet*0.3 THEN '🔴 CIDDI EKSIK'
            WHEN s.adet < g.sezon_adet*0.7 THEN '🟡 EKSIK'
            ELSE '🟢 YETERLI' END AS durum
  FROM stok s FULL JOIN gecmis g ON g.marka=s.marka
 WHERE COALESCE(g.sezon_adet,0) > 100
 ORDER BY g.sezon_adet DESC NULLS LAST;"
echo "  ^ karsilama_pct = eldeki stok / gecen sezon satisi."
echo "    ⚠ %100 hedef DEGIL — sezon icinde ek alim yapilir. Ama %30'un altindaysa"
echo "      ON SIPARIS SART. Toplam kis stogu 4.329 adet, gecen sezon satisi cok daha fazlaydi."

echo
echo "############ 4) EŞIK — erken alim primi kac olmali? ############"
$PSQL -c "
SELECT 40.0 AS sermaye_maliyeti_yillik_pct,
       65 AS erken_odeme_gun,
       round(40.0 * 65 / 365, 1) AS ERKEN_ALIM_MALIYETI_PCT,
       'kesin_siparis_pct > 7,1 ise ERKEN AL' AS karar_kurali;"
echo
echo "  ⚠ bi_tedarikci_tesvik.kesin_siparis_pct = 0.00 (TUM MARKALARDA)."
echo "     Alan VAR, deger YOK. Bu doldurulmadan model KARAR VEREMEZ."
echo "     Doldurulunca: her ebat icin 'erken al' / 'bekle' otomatik cikar."
echo
echo "  ⚠ Conti (Fatih Bilen notu): Kas-Ara-Oca 3 taksit -> odeme DAHA GEC"
echo "     -> Conti'de erken almanin finansman maliyeti Brisa'dan DUSUK."
echo "     Conti taksit takvimi netlesince ayri esik hesaplanacak."
