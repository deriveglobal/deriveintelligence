#!/usr/bin/env bash
# Salt okuma. Alis (tedarikci) tablosunun TAM semasi lazim.
# Satista 'birim_fiyat = Indirim Sonrasi Fiyat' surprizini yasadik;
# burada da hangi kolonun neye karsilik geldigini TAHMIN ETMEYECEGIM.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) bi_tedarikci_faturalari — TAM SEMA ############"
$PSQL -c "\d bi_tedarikci_faturalari"

echo
echo "############ 2) MEVCUT VERI — ne var, ne kadar, hangi yillar? ############"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil, count(*) AS satir,
       round(sum(satir_kdv_haric)/1e6,2) AS alis_MTL,
       min(fatura_tarihi) AS ilk, max(fatura_tarihi) AS son
  FROM bi_tedarikci_faturalari WHERE tenant_id::text = '$TEN'
 GROUP BY 1 ORDER BY 1;"

echo
echo "############ 3) ⚠ TARIH BOZUKLUGU alista da var mi? ############"
$PSQL -c "
SELECT count(*) AS toplam,
       count(*) FILTER (WHERE fatura_tarihi > CURRENT_DATE)  AS gelecek_BOZUK,
       count(*) FILTER (WHERE vade_tarihi < fatura_tarihi)   AS ters_BOZUK,
       max(fatura_tarihi) AS en_uc_tarih
  FROM bi_tedarikci_faturalari WHERE tenant_id::text = '$TEN';"
echo "  ^ satista 1.419 gelecek tarihli vardi. Burada da bekleniyor."

echo
echo "############ 4) ARITMETIK: hangi kolon ciftini tutturuyor? ############"
echo "  (satista birim_fiyat = 'Indirim Sonrasi Fiyat' cikmisti)"
$PSQL -c "
SELECT count(*) AS test,
       count(*) FILTER (WHERE abs(miktar*birim_fiyat_kdv_haric - satir_kdv_haric)
                              <= GREATEST(0.05, abs(satir_kdv_haric)*0.02)) AS kdv_haric_TUTUYOR,
       count(*) FILTER (WHERE abs(miktar*birim_fiyat_kdv_dahil - satir_kdv_dahil)
                              <= GREATEST(0.05, abs(satir_kdv_dahil)*0.02)) AS kdv_dahil_TUTUYOR
  FROM bi_tedarikci_faturalari
 WHERE tenant_id::text='$TEN' AND satir_kdv_haric <> 0;"

echo
echo "############ 5) vade_gun / vade_tarihi nasil doldurulmus? ############"
echo "  ⚠ Excel'de VADE TARIHI KOLONU YOK — sadece 'Payment Terms Code' (90 Gun Vade)."
echo "     Yani vade_tarihi TURETILMIS olmali. Nasil?"
$PSQL -c "
SELECT vade_gun, count(*) AS satir,
       count(*) FILTER (WHERE vade_tarihi = fatura_tarihi + vade_gun) AS tarih_gun_ile_UYUMLU,
       count(*) FILTER (WHERE vade_tarihi IS NULL)                     AS vade_tarihi_NULL
  FROM bi_tedarikci_faturalari WHERE tenant_id::text='$TEN'
 GROUP BY 1 ORDER BY 2 DESC LIMIT 10;"

echo
echo "############ 6) ORNEK 3 SATIR (kolonlarin gercek icerigi) ############"
$PSQL -x -c "
SELECT * FROM bi_tedarikci_faturalari WHERE tenant_id::text='$TEN'
 ORDER BY fatura_tarihi DESC LIMIT 2;"

echo
echo "############ 7) urun master alistan maliyet cekiyor mu? ############"
grep -rn "bi_tedarikci_faturalari" /opt/price_monitor/*.py 2>/dev/null | head -5
echo "  ^ cekiyorsa: alis yuklenince maliyet/marj otomatik duzelecek."
