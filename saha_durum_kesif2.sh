#!/usr/bin/env bash
# SAHA_DURUM_KESIF_2 — kolon adi fatura_tarihi'ymis (belge_tarihi degil). Duzeltildi.
#
# ⚠ ILK KESIF SUNU GOSTERDI:  1.028 musterinin  1 (BIR) tanesi AKTIF_MUSTERI.
#   893'u ESKI_NOKTA. KRB'nin yuzlerce calisan bayisi var.
#   Yani "12 musterinin durumu yanlis" DEGIL — alan ZATEN SUS.
#   Excel ice aktarimindan gelen varsayilan, ustune kimse dokunmamis.
#   ⚠ Bu yuzden "12 kaydi duzeltelim" onerimi geri cekiyorum. Sorun kayit degil, YONTEM.
#
# Simdi 13 degil, 1.028'in TAMAMINI ERP gercegiyle karsilastiriyorum.
# HICBIR SEY DEGISTIRMIYOR — sadece olcuyor.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) EKRAN NE DIYOR / ERP NE DIYOR — 1.028 musteri ############"
$PSQL -c "
WITH erp AS (
  SELECT musteri_kodu, count(*) AS fatura, max(fatura_tarihi) AS son_satis
    FROM bi_satis_faturalari GROUP BY musteri_kodu
),
k AS (
  SELECT m.durum AS ekranda,
         CASE
           WHEN m.musteri_kodu IS NULL      THEN 'ERP KODU YOK'
           WHEN e.musteri_kodu IS NULL      THEN 'HIC SATIS YOK  -> gercek YENI'
           WHEN e.son_satis > current_date -  90 THEN 'AKTIF   (son 90 gun)'
           WHEN e.son_satis > current_date - 365 THEN 'UYUYAN  (1 yil ici)'
           ELSE                                       'ESKI    (1 yildan eski)'
         END AS erp_gercegi
    FROM saha_musteri m
    LEFT JOIN erp e ON e.musteri_kodu = m.musteri_kodu
   WHERE m.aktif
)
SELECT ekranda, erp_gercegi, count(*)
  FROM k GROUP BY 1,2 ORDER BY 3 DESC;"

echo
echo "############ 2) ⚠ CELISKININ BUYUKLUGU ############"
$PSQL -c "
WITH erp AS (
  SELECT musteri_kodu, max(fatura_tarihi) AS son_satis
    FROM bi_satis_faturalari GROUP BY musteri_kodu
)
SELECT
  count(*) FILTER (WHERE e.son_satis > current_date - 90)                          AS erp_de_aktif,
  count(*) FILTER (WHERE m.durum = 'AKTIF_MUSTERI')                                AS ekranda_aktif,
  count(*) FILTER (WHERE e.son_satis > current_date - 90
                     AND m.durum <> 'AKTIF_MUSTERI')                               AS aktif_ama_oyle_yazmiyor,
  count(*) FILTER (WHERE m.durum = 'YENI_NOKTA' AND e.son_satis IS NOT NULL)       AS yeni_diyor_ama_satis_var,
  count(*) FILTER (WHERE m.durum = 'ESKI_NOKTA'
                     AND e.son_satis > current_date - 90)                          AS eski_diyor_ama_bu_ay_satis_var
  FROM saha_musteri m
  LEFT JOIN erp e ON e.musteri_kodu = m.musteri_kodu
 WHERE m.aktif;"

echo
echo "############ 3) EFTAL'IN 13'U — ekran vs ERP, tek tek ############"
$PSQL -c "
WITH hedef AS (
  SELECT DISTINCT mu.id, mu.firma, mu.musteri_kodu, mu.durum
    FROM saha_hata_log h
    JOIN saha_musteri mu ON mu.id = replace(h.endpoint,'/api/saha/musteriler/','')::uuid
   WHERE h.user_id='ae0c55f9-68cc-421d-96d9-409222452f1a'
     AND h.http_status=403 AND h.ts >= current_date - 2
)
SELECT left(h.firma,32) AS musteri, h.durum AS ekranda,
       e.fatura, e.ilk_satis, e.son_satis,
       CASE
         WHEN h.musteri_kodu IS NULL     THEN 'ERP kodu yok'
         WHEN e.fatura IS NULL           THEN 'hic satis yok'
         WHEN e.son_satis > current_date -  90 THEN 'AKTIF'
         WHEN e.son_satis > current_date - 365 THEN 'UYUYAN'
         ELSE 'ESKI'
       END AS erp_gercegi
  FROM hedef h
  LEFT JOIN LATERAL (
    SELECT count(*) AS fatura, min(fatura_tarihi) AS ilk_satis, max(fatura_tarihi) AS son_satis
      FROM bi_satis_faturalari f
     WHERE f.musteri_kodu = h.musteri_kodu
  ) e ON true
 ORDER BY e.son_satis DESC NULLS LAST;"

echo
echo "⚠ 'ekranda' sutunu ile 'erp_gercegi' sutunu ayrisiyorsa:"
echo "  durum bir OLGU degil, bir KANAAT. Ve kimse o kanaati guncellemiyor."
