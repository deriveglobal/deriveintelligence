#!/usr/bin/env bash
# Salt okuma. ⚠ YENI FIYAT LISTESI 'Tavsiye Edilen PERAKENDE Satis Fiyati, KDV DAHIL'.
#   Mevcut bi_fiyat_listesi_kalemler hangi konvansiyonda?
#   Yanlis basarsam maliyet %20 siser -> marj yanlis -> yanlis red kararlari.
#   OLCMEDEN YUKLEMEM.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SEMA ############"
$PSQL -c "\d bi_fiyat_listesi_uploads" | head -20
$PSQL -c "\d bi_fiyat_listesi_kalemler" | head -20

echo
echo "############ 2) MEVCUT LISTELER ############"
$PSQL -c "
SELECT u.id, u.marka, u.sezon, u.aktif, count(k.id) AS kalem,
       round(min(k.liste_fiyati)) AS min_TL, round(max(k.liste_fiyati)) AS max_TL,
       round(avg(k.liste_fiyati)) AS ort_TL
  FROM bi_fiyat_listesi_uploads u
  LEFT JOIN bi_fiyat_listesi_kalemler k ON k.upload_id = u.id
 WHERE u.tenant_id='$TEN'::uuid
 GROUP BY 1,2,3,4 ORDER BY 2,3;" 2>&1 | head -20

echo
echo "############ 3) ⚠⚠ KONVANSIYON TESTI — KDV DAHIL mi HARIC mi? ############"
echo "   YENI LISTE (Brisa dosyasi, perakende KDV DAHIL):"
echo "     LASSA 205/55R16 KIS = 8.974 TL"
echo "     LASSA 185/65R15 KIS = 5.926 TL"
echo "     LASSA 235/65R16C    = 12.960 TL"
echo
echo "   MEVCUT TABLODA ayni ebatlar ne diyor?"
$PSQL -c "
SELECT u.marka, u.sezon, k.ebat, round(k.liste_fiyati) AS mevcut_liste_TL
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id = k.upload_id
 WHERE k.tenant_id='$TEN'::uuid AND u.aktif
   AND k.ebat IN ('205/55R16','185/65R15','235/65R16C','195/65R15')
 ORDER BY u.marka, k.ebat;" 2>&1 | head -25
echo
echo "  >>> NASIL OKUNUR:"
echo "      Mevcut ~7.480 ise -> KDV HARIC (8.974/1,20 = 7.478). Yeni listeyi /1,20 yap."
echo "      Mevcut ~8.974 ise -> KDV DAHIL. Aynen bas."
echo "      Mevcut ~4.800 ise -> BAYI listesi (perakende degil). BASKA BIR SEY. DUR."

echo
echo "############ 4) ⚠ CAPRAZ KONTROL — teshvik uygulanmis maliyet, gercek alisla tutuyor mu? ############"
echo "   LASSA KIS baz iskonto %35 (bi_fiyat_iskonto)."
echo "   Eger liste KDV haric 7.478 ise: 7.478 x (1-0,35) = 4.861 TL beklenen maliyet."
echo "   GERCEK son alis fiyatimiz ne?"
$PSQL -c "
SELECT t.marka, t.kategori, count(*) AS satir,
       round(avg(t.birim_fiyat_kdv_haric)) AS ort_alis_TL,
       round(max(t.fatura_tarihi)::date - CURRENT_DATE) AS gun
  FROM bi_tedarikci_faturalari t
 WHERE t.tenant_id='$TEN'::uuid AND t.miktar > 0
   AND upper(t.marka) = 'LASSA' AND t.kategori ILIKE '%KIS%'
   AND t.kalem_tanimi ILIKE '205/55R16%'
   AND t.fatura_tarihi >= CURRENT_DATE - 400
 GROUP BY 1,2;"
echo "  ^ ~4.861 civariysa: liste KDV HARIC + %35 iskonto DOGRULANDI."
echo "    Cok farkliysa: iskonto yapisi ya da liste tabani BASKA. Yuklemeden ONCE anla."

echo
echo "############ 5) MEVCUT LISTE HANGI SEZONLARI KAPSIYOR? (bosluk) ############"
$PSQL -c "
SELECT u.marka,
       count(*) FILTER (WHERE u.sezon ILIKE '%KIS%' OR u.sezon ILIKE '%KIŞ%') AS kis,
       count(*) FILTER (WHERE u.sezon ILIKE '%YAZ%') AS yaz,
       count(*) FILTER (WHERE u.sezon ILIKE '%4%' OR u.sezon ILIKE '%DÖRT%') AS dort_mevsim,
       string_agg(DISTINCT u.sezon, ', ') AS sezonlar
  FROM bi_fiyat_listesi_uploads u
 WHERE u.tenant_id='$TEN'::uuid AND u.aktif
 GROUP BY 1 ORDER BY 1;" 2>&1 | head -12
echo "  ^ YAZ ve 4 MEVSIM sutunlari 0 ise: yeni dosya BU BOSLUGU kapatiyor."
echo "    1.274 satir (LASSA+BRIDGESTONE+DAYTON, yaz+kis+4mevsim) hazir."
