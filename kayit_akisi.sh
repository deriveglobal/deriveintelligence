#!/usr/bin/env bash
# KAYIT_AKISI — Fatih hakli: "yeni mi" sorusu ZATEN KAYIT ANINDA cevaplaniyor.
#
# ⚠ DURUM_UYGULA.SH'I CALISTIRMA. Onu geri cekiyorum.
#   O script 'ESLESMEMIS' diye YENI BIR DURUM ekliyordu — oysa bu bir FAALIYET
#   durumu degil, bir KIMLIK durumu. Ve kimlik ZATEN var: erp_eslestirme_tipi
#   (ESLESTI / BEKLIYOR / YENI_NOKTA), GET musteri detayinda hesaplaniyor.
#   Ayni bilgiyi ikinci bir yere yazacaktim. Iki kaynak, er ya da gec CELISIR.
#
# ⚠ ASIL TESHIS: 'durum' alani IKI AYRI SORUYU tek kutuya tikmis:
#     KIMLIK   : Bu firma ERP'de var mi?      -> kayit aninda belli (musteri_kodu)
#     FAALIYET : Bu firma alisveris yapiyor mu? -> satis gecmisinden okunur, DEGISIR
#   Bir firma ERP'de kayitli OLABILIR ve iki yildir hicbir sey ALMAMIS olabilir.
#   Tek etiketle ikisini birden soyleyemezsin.
#
# Bu script SADECE OKUR. Once akisi kendi gozumle gorecegim.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) KAYIT AKISI — temsilci yeni musteriyi nasil ekliyor? ############"
grep -n "master_musteri\|ERP'den ara\|erp-ara\|musteri-ara\|YENI_NOKTA\|yeni nokta" shells/saha.js | head -20

echo
echo "############ 2) master_musteri — arama havuzu ############"
$PSQL -c "SELECT count(*) AS master_kayit FROM master_musteri;"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='master_musteri' ORDER BY ordinal_position;"

echo
echo "############ 3) KIMLIK ZATEN VAR MI? erp_eslestirme_tipi dagilimi ############"
$PSQL -c "
SELECT CASE
         WHEN m.musteri_kodu IS NOT NULL THEN 'ESLESTI     (ERP kodu var)'
         WHEN eo.id IS NOT NULL          THEN 'BEKLIYOR    (eslestirme onerisi var)'
         ELSE                                 'YENI_NOKTA  (ERPde yok, gercekten yeni)'
       END AS kimlik,
       count(*)
  FROM saha_musteri m
  LEFT JOIN saha_eslestirme_oneri eo ON eo.saha_musteri_id = m.id AND eo.durum='BEKLIYOR'
 WHERE m.aktif
 GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 4) ⚠ IKI EKSEN YAN YANA — karisikligin kaniti ############"
$PSQL -c "
WITH erp AS (SELECT musteri_kodu, max(fatura_tarihi) s, count(*) f FROM bi_satis_faturalari GROUP BY 1)
SELECT
  CASE WHEN m.musteri_kodu IS NOT NULL THEN 'ERPde VAR' ELSE 'ERPde YOK' END AS kimlik,
  CASE
    WHEN e.s IS NULL                  THEN 'hic satis yok'
    WHEN e.s > current_date -  90     THEN 'AKTIF  (son 90 gun)'
    WHEN e.s > current_date - 365     THEN 'UYUYAN (1 yil ici)'
    ELSE                                   'ESKI   (1 yildan eski)'
  END AS faaliyet,
  count(*)
  FROM saha_musteri m LEFT JOIN erp e ON e.musteri_kodu = m.musteri_kodu
 WHERE m.aktif
 GROUP BY 1,2 ORDER BY 1, 3 DESC;"
echo
echo "  ⚠ 'ERPde VAR' + 'ESKI/UYUYAN' satirlari:  kayitli musteri, ama ALMIYOR."
echo "     Tek etiketle bunu anlatamazsin. IKI EKSEN gerek."
