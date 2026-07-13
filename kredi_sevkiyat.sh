#!/usr/bin/env bash
# ⚠⚠ ON SIPARIS x KREDI RISKI CAKISMASI
#
# KRB kis on siparisini VERDI. Bunun 24.842 adedi MUSTERIYE ON SATIS:
#   MUTAFLAR : 17.570 adet (Brisa) + 3.680 (Conti) = 21.250
#   YEDI OTO :  7.272 adet (Brisa)
#   BAR OTO  :  3.448 adet (Conti)
#
# ⚠ MUTAFLAR ve YEDI OTO, bugun olctugumuz LIMIT ASAN MUSTERI listesinin
#   ILK IKISI:
#     MUTAFLAR : limit  1,0M · risk 47,5M · gecikmis 49,4M · ASIM 46,5M
#     YEDI OTO : limit 15,0M · risk 30,9M · gecikmis 19,0M · ASIM 15,9M
#   Ikisi KRB'nin TOPLAM gecikmis alacaginin %47'si. Ikisi de Eftal Yildiz'in.
#
# SORU: bu sevkiyat ne kadar YENI ALACAK yaratacak — ve KRB Brisa'ya
#       18 Kasim / 16 Aralik'ta odeyecek. Makas tutuyor mu?
#
# ⚠ PERAKENDE LISTE FIYATI KULLANMIYORUZ. Bu musteriler TOPTAN.
#   KRB'nin onlara FIILEN sattigi fiyati kullaniyoruz. Gercek, tahmin degil.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) BU MUSTERILERE GERCEKTE KACA SATIYORUZ? ############"
$PSQL -c "
SELECT f.musteri_adi,
       count(*) AS satir,
       round(sum(f.miktar)) AS adet,
       round(sum(f.satir_tutar)/1e6,1) AS ciro_MTL,
       round(sum(f.satir_tutar)/NULLIF(sum(f.miktar),0)) AS ort_birim_TL,
       round(avg(f.vade_tarihi - f.fatura_tarihi)) AS ort_vade_gun
  FROM bi_satis_faturalari f
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.miktar > 0
   AND (f.musteri_adi ILIKE '%MUTAFLAR%' OR f.musteri_adi ILIKE '%YEDİ OTO%'
        OR f.musteri_adi ILIKE '%YEDI OTO%' OR f.musteri_adi ILIKE '%BAR OTO%')
   AND f.fatura_tarihi >= CURRENT_DATE - 365
 GROUP BY 1 ORDER BY 4 DESC;"
echo "  ^ ort_birim_TL = bu musterilere GERCEK satis fiyatimiz (toptan)."

echo
echo "############ 2) ⚠⚠ SEVKIYAT SONRASI RISK — bugunku risk + yeni alacak ############"
$PSQL -c "
WITH gercek_fiyat AS (
  SELECT CASE WHEN musteri_adi ILIKE '%MUTAFLAR%' THEN 'MUTAFLAR'
              WHEN musteri_adi ILIKE '%YEDİ OTO%' OR musteri_adi ILIKE '%YEDI OTO%' THEN 'YEDI OTO'
              WHEN musteri_adi ILIKE '%BAR OTO%' THEN 'BAR OTO' END AS m,
         SUM(satir_tutar)/NULLIF(SUM(miktar),0) AS birim
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
     AND fatura_tarihi >= CURRENT_DATE - 365
     AND (musteri_adi ILIKE '%MUTAFLAR%' OR musteri_adi ILIKE '%YEDİ OTO%'
          OR musteri_adi ILIKE '%YEDI OTO%' OR musteri_adi ILIKE '%BAR OTO%')
   GROUP BY 1),
siparis(m, adet) AS (VALUES ('MUTAFLAR', 21250), ('YEDI OTO', 7272), ('BAR OTO', 3448)),
risk AS (
  SELECT CASE WHEN muhatap_adi ILIKE '%MUTAFLAR%' THEN 'MUTAFLAR'
              WHEN muhatap_adi ILIKE '%YEDİ OTO%' OR muhatap_adi ILIKE '%YEDI OTO%' THEN 'YEDI OTO'
              WHEN muhatap_adi ILIKE '%BAR OTO%' THEN 'BAR OTO' END AS m,
         kredi_limiti, toplam_risk, vadesi_gecmis
    FROM bi_musteri_risk
   WHERE tenant_id='$TEN'::uuid AND musteri_mi
     AND (muhatap_adi ILIKE '%MUTAFLAR%' OR muhatap_adi ILIKE '%YEDİ OTO%'
          OR muhatap_adi ILIKE '%YEDI OTO%' OR muhatap_adi ILIKE '%BAR OTO%'))
SELECT s.m AS musteri,
       s.adet AS siparis_adet,
       round(g.birim) AS birim_TL,
       round(s.adet * g.birim / 1e6, 1) AS YENI_ALACAK_MTL,
       round(r.kredi_limiti/1e6,1) AS limit_MTL,
       round(r.toplam_risk/1e6,1) AS bugunku_risk_MTL,
       round(r.vadesi_gecmis/1e6,1) AS gecikmis_MTL,
       round((r.toplam_risk + s.adet*g.birim)/1e6,1) AS SEVKIYAT_SONRASI_RISK_MTL,
       round((r.toplam_risk + s.adet*g.birim) / NULLIF(r.kredi_limiti,0)) AS LIMITIN_KAC_KATI
  FROM siparis s
  LEFT JOIN gercek_fiyat g ON g.m = s.m
  LEFT JOIN risk r         ON r.m = s.m
 ORDER BY 4 DESC NULLS LAST;"
echo
echo "  ⚠ LIMITIN_KAC_KATI: sevkiyat sonrasi risk / kredi limiti."
echo "    MUTAFLAR'in limiti 1M. Bu sayi ne cikarsa, o kadar kat asilmis olacak."

echo
echo "############ 3) ⚠ TAHSILAT PERFORMANSI — bu musteriler odüyor mu? ############"
$PSQL -c "
SELECT t.musteri_adi,
       count(*) AS fatura,
       round(sum(t.fatura_tutari)/1e6,1) AS tutar_MTL,
       round(sum(t.fatura_tutari*t.tahsilat_gun)/NULLIF(sum(t.fatura_tutari),0),1) AS DSO_gun,
       round(100.0*count(*) FILTER (WHERE t.gecikme_gun > 0)/NULLIF(count(*),0)) AS gec_odenen_pct,
       max(t.gecikme_gun) AS en_uzun_gecikme_gun
  FROM bi_fatura_tahsilat t
 WHERE t.tenant_id='$TEN'::uuid AND t.tahsilat_gun IS NOT NULL
   AND (t.musteri_adi ILIKE '%MUTAFLAR%' OR t.musteri_adi ILIKE '%YEDİ OTO%'
        OR t.musteri_adi ILIKE '%YEDI OTO%' OR t.musteri_adi ILIKE '%BAR OTO%')
 GROUP BY 1 ORDER BY 3 DESC;"
echo "  ^ Gecmiste NASIL odemisler? DSO yuksekse yeni alacak da gec gelecek."

echo
echo "############ 4) ⚠⚠ NAKIT MAKASI — KRB ne zaman odeyecek, ne zaman tahsil edecek? ############"
echo "   BRISA TAKSIT TAKVIMI (KRB'nin kendi slaydi):"
echo "     1.DONEM (Tem/Agu/Eyl faturasi) -> 18 KASIM + 16 ARALIK"
echo "     2.DONEM (Eki/Kas/Ara faturasi) -> 22 OCAK  + 22 SUBAT"
echo
echo "   BRISA KIS SIPARISI: 1.donem 18.372 adet · 2.donem 19.372 adet"
echo "     KRB kendi     : 1.don 7.760 · 2.don 5.142"
echo "     Mutaflar      : 1.don 10.612 · 2.don 6.958"
echo "     Yedi Oto      : 1.don      0 · 2.don 7.272"
echo
echo "   ⚠ KRB, Mutaflar'in 10.612 adedini KASIM'da Brisa'ya ODEYECEK."
echo "     Mutaflar'in bugunku gecikmis alacagi 49,4M ve DSO'su yukarida."
echo "     Bu adetin parasi Kasim'a kadar gelmezse, KRB kendi cebinden oder."

echo
echo "############ 5) ELDEKI NAKIT ALANI ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok AS (SELECT SUM(s.adet*son.m) d FROM bi_stok_anlik s JOIN son ON son.kalem_kodu=s.kalem_kodu
          WHERE s.tenant_id='$TEN'::uuid),
alacak AS (SELECT SUM(toplam_risk) a, SUM(vadesi_gecmis) g FROM bi_musteri_risk
            WHERE tenant_id='$TEN'::uuid AND musteri_mi)
SELECT round(stok.d/1e6) AS stokta_bagli_MTL,
       round(alacak.a/1e6) AS alacakta_bagli_MTL,
       round(alacak.g/1e6) AS bunun_gecikmis_MTL,
       round((stok.d+alacak.a)/1e6) AS TOPLAM_BAGLI_MTL
  FROM stok, alacak;"
echo "  ^ Uzerine kis siparisinin odemesi gelecek. Kasim-Aralik'ta."
