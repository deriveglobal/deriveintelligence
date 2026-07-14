#!/usr/bin/env bash
# SAHA_DURUM_KESIF — "yeni mi, mevcut mu" sorusunu SISTEM NASIL CEVAPLIYOR?
#
# ⚠ Fatih'in sorusu dogru yerden geliyor:
#   "yeni / mevcut" bir KANAAT degil, bir OLGU olmali — satis gecmisinden okunur.
#   Eger bugun bunu temsilci bir açilir listeden ELIYLE seciyorsa,
#   o zaman "duzelt" dedigim 12 kayit bir veri sorunu degil, TASARIM sorunudur.
#   Once olcuyorum, sonra konusuyorum. Hicbir sey degistirmiyor.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) durum alani — izinli degerler ve kim yaziyor? ############"
$PSQL -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint
          WHERE conrelid='saha_musteri'::regclass AND conname LIKE '%durum%';"
echo "  --- 1.028 musteri nasil dagilmis? ---"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"
echo "  --- durum'u KIM belirliyor? (kod) ---"
grep -rn "durum" shells/saha.js | grep -i "select\|option\|pt-durum\|DURUM_ETIKET" | head -8
echo "  ⚠ Eger bu bir <select> ise: durum ELLE seciliyor demektir — olgu degil, kanaat."

echo
echo "############ 2) ERP SATIS GECMISI — baglanti var mi? ############"
echo "  --- kac saha musterisinin ERP kodu var? ---"
$PSQL -c "
SELECT count(*) AS toplam,
       count(musteri_kodu) AS erp_kodu_var,
       count(*) - count(musteri_kodu) AS erp_kodu_yok
  FROM saha_musteri WHERE aktif;"
echo "  --- satis faturalarinda musteri hangi kolonda? ---"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_satis_faturalari'
            AND (column_name ILIKE '%musteri%' OR column_name ILIKE '%cari%'
                 OR column_name ILIKE '%kod%' OR column_name ILIKE '%tarih%')
          ORDER BY ordinal_position;"

echo
echo "############ 3) ⚠ OLGU: bu 13 musteri ERP'de gercekten ne? ############"
echo "  (durum='YENI_NOKTA' diyor — satis gecmisi ne diyor?)"
$PSQL -c "
WITH hedef AS (
  SELECT DISTINCT mu.id, mu.firma, mu.musteri_kodu, mu.durum
    FROM saha_hata_log h
    JOIN saha_musteri mu ON mu.id = replace(h.endpoint,'/api/saha/musteriler/','')::uuid
   WHERE h.user_id='ae0c55f9-68cc-421d-96d9-409222452f1a'
     AND h.http_status=403 AND h.ts >= current_date - 1
)
SELECT h.firma, h.durum AS ekranda,
       s.fatura_sayisi, s.ilk_satis, s.son_satis,
       CASE
         WHEN s.fatura_sayisi IS NULL         THEN 'ERP''de HIC SATIS YOK'
         WHEN s.son_satis > current_date - 90 THEN 'AKTIF (son 90 gun)'
         WHEN s.son_satis > current_date -365 THEN 'UYUYAN (1 yil icinde)'
         ELSE 'ESKI (1 yildan eski)'
       END AS erp_gercegi
  FROM hedef h
  LEFT JOIN LATERAL (
    SELECT count(*) AS fatura_sayisi,
           min(belge_tarihi) AS ilk_satis,
           max(belge_tarihi) AS son_satis
      FROM bi_satis_faturalari f
     WHERE h.musteri_kodu IS NOT NULL AND f.musteri_kodu = h.musteri_kodu
  ) s ON true
 ORDER BY s.son_satis DESC NULLS LAST;"
echo
echo "  ⚠ 'ekranda' ile 'erp_gercegi' ayrisiyorsa: sorun 12 kayit degil, YONTEM."
