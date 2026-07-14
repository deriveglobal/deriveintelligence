#!/usr/bin/env bash
# DURUM_PROVA — HICBIR SEY DEGISTIRMEZ. Sadece "uygulasak ne olurdu"yu gosterir.
#
# ⚠ KARAR: durum artik ELLE YAZILMAYACAK, ERP'den HESAPLANACAK.
#
# ⚠ DURUSTLUK SORUNU — ve cozumu:
#   235 musterinin ERP KODU YOK. Bunlara "YENI" demek YALAN olur:
#   gercekten yeni mi, yoksa sadece eslestirilmemis mi — BILMIYORUZ.
#   Eftal'in ER OTO LASTIK'i gercekten yeni ("cari ve b2b acilisini saglamistik,
#   henuz satis gerceklestiremedik"), ama diger 234 icin ayni seyi soyleyemem.
#   -> Ayri ve DURUST bir etiket: ESLESMEMIS = "ERP eslesmesi yok, durum bilinmiyor."
#   Bilmedigimiz seye isim vermek, YANLIS isim vermekten iyidir.
#
# ⚠ RISKLI_NOKTA bu alandan CIKIYOR: risk ayri bir eksen (vadesi gecmis bakiye).
#   Aktif bir musteri ayni anda riskli olabilir; ikisi ayni kutuya girmemeli.
#
# KURAL:
#   ERP kodu yok            -> ESLESMEMIS   (bilmiyoruz, oyle de soyluyoruz)
#   kod var, hic fatura yok -> YENI_NOKTA   (gercekten yeni)
#   son satis <=  90 gun    -> AKTIF_MUSTERI
#   son satis <= 365 gun    -> PASIF_NOKTA  (uyuyan)
#   daha eski               -> ESKI_NOKTA
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ PROVA — ne degisirdi? (YAZMA YOK) ############"
$PSQL -c "
WITH erp AS (
  SELECT musteri_kodu, count(*) AS fatura, max(fatura_tarihi) AS son_satis
    FROM bi_satis_faturalari GROUP BY musteri_kodu
),
h AS (
  SELECT m.id, m.firma, m.durum AS simdiki,
         CASE
           WHEN m.musteri_kodu IS NULL OR e.musteri_kodu IS NULL AND m.musteri_kodu IS NULL
                                                  THEN 'ESLESMEMIS'
           WHEN e.musteri_kodu IS NULL            THEN 'YENI_NOKTA'
           WHEN e.son_satis > current_date -  90  THEN 'AKTIF_MUSTERI'
           WHEN e.son_satis > current_date - 365  THEN 'PASIF_NOKTA'
           ELSE                                        'ESKI_NOKTA'
         END AS hesaplanan
    FROM saha_musteri m
    LEFT JOIN erp e ON e.musteri_kodu = m.musteri_kodu
   WHERE m.aktif
)
SELECT simdiki, hesaplanan, count(*),
       CASE WHEN simdiki = hesaplanan THEN 'ayni' ELSE '⚠ DEGISIR' END AS sonuc
  FROM h GROUP BY 1,2 ORDER BY 3 DESC;"

echo
echo "############ 2) OZET ############"
$PSQL -c "
WITH erp AS (
  SELECT musteri_kodu, max(fatura_tarihi) AS son_satis
    FROM bi_satis_faturalari GROUP BY musteri_kodu
),
h AS (
  SELECT m.durum AS simdiki,
         CASE
           WHEN m.musteri_kodu IS NULL           THEN 'ESLESMEMIS'
           WHEN e.musteri_kodu IS NULL           THEN 'YENI_NOKTA'
           WHEN e.son_satis > current_date -  90 THEN 'AKTIF_MUSTERI'
           WHEN e.son_satis > current_date - 365 THEN 'PASIF_NOKTA'
           ELSE                                       'ESKI_NOKTA'
         END AS hesaplanan
    FROM saha_musteri m
    LEFT JOIN erp e ON e.musteri_kodu = m.musteri_kodu
   WHERE m.aktif
)
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE simdiki = hesaplanan) AS dogru_zaten,
       count(*) FILTER (WHERE simdiki <> hesaplanan) AS duzelecek
  FROM h;"

echo
echo "############ 3) YENI DAGILIM — uygulaninca ekran ne diyecek? ############"
$PSQL -c "
WITH erp AS (
  SELECT musteri_kodu, max(fatura_tarihi) AS son_satis
    FROM bi_satis_faturalari GROUP BY musteri_kodu
)
SELECT CASE
         WHEN m.musteri_kodu IS NULL           THEN 'ESLESMEMIS   (bilinmiyor)'
         WHEN e.musteri_kodu IS NULL           THEN 'YENI_NOKTA   (hic fatura yok)'
         WHEN e.son_satis > current_date -  90 THEN 'AKTIF_MUSTERI(son 90 gun)'
         WHEN e.son_satis > current_date - 365 THEN 'PASIF_NOKTA  (uyuyan)'
         ELSE                                       'ESKI_NOKTA   (1 yildan eski)'
       END AS yeni_durum, count(*)
  FROM saha_musteri m LEFT JOIN erp e ON e.musteri_kodu = m.musteri_kodu
 WHERE m.aktif GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 4) ⚠ RISKLI_NOKTA — kaybolmuyor, TASINIYOR ############"
$PSQL -c "SELECT id, firma, durum FROM saha_musteri WHERE durum='RISKLI_NOKTA' AND aktif;"
echo "  ⚠ Bu 2 kayit AKTIFLIK ekseninde yeniden hesaplanacak."
echo "     Risk, bakiyeden gelen AYRI bir isaret olarak gosterilecek — silinmiyor."
echo
echo "⚠ HICBIR SEY YAZILMADI. Rakamlari gor, sonra uygulariz."
