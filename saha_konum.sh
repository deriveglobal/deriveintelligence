#!/usr/bin/env bash
# SAHA_KONUM — Eftal'in check-in koordinatlari.
#
# ⚠ Sadece OKUR. Ayrica sunu da olcer: check-in koordinati ile MUSTERININ kendi
#   koordinati arasindaki mesafe. Cunku "check-in var" demek "oradaydi" demek DEGIL —
#   musterinin lat/lng'si bosss veya yanlissa mesafe hesaplanamaz, bunu da soyleyecegim.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) saha_ziyaret — konum hangi kolonlarda? (varsayim yok) ############"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='saha_ziyaret'
            AND (column_name ILIKE '%lat%' OR column_name ILIKE '%lng%' OR column_name ILIKE '%lon%'
                 OR column_name ILIKE '%konum%' OR column_name ILIKE '%checkin%' OR column_name ILIKE '%check_in%')
          ORDER BY ordinal_position;"

echo
echo "############ 2) ⚠ EFTAL — 13 Tem check-in'leri, koordinatlariyla ############"
$PSQL -c "
SELECT to_char(z.ziyaret_tarihi,'DD Mon') AS tarih,
       to_char(z.created_at AT TIME ZONE 'Europe/Istanbul','HH24:MI') AS saat,
       left(mu.firma, 34) AS musteri,
       z.lat  AS ziyaret_lat,
       z.lng  AS ziyaret_lng,
       mu.lat AS musteri_lat,
       mu.lng AS musteri_lng,
       CASE
         WHEN z.lat IS NULL OR z.lng IS NULL THEN 'CHECK-IN YOK'
         WHEN mu.lat IS NULL OR mu.lng IS NULL THEN 'musterinin konumu YOK -> olculemez'
         ELSE round((6371000 * acos(LEAST(1, GREATEST(-1,
                cos(radians(z.lat)) * cos(radians(mu.lat)) *
                cos(radians(mu.lng) - radians(z.lng)) +
                sin(radians(z.lat)) * sin(radians(mu.lat))
              ))))::numeric) || ' m'
       END AS mesafe
  FROM saha_ziyaret z
  LEFT JOIN saha_musteri mu ON mu.id = z.musteri_id
 WHERE z.rep_id = 'ae0c55f9-68cc-421d-96d9-409222452f1a'
   AND z.ziyaret_tarihi >= current_date - 2
 ORDER BY z.created_at;"

echo
echo "############ 3) OZET — kacinda check-in var, kacinda olculebiliyor? ############"
$PSQL -c "
SELECT count(*) AS ziyaret,
       count(z.lat) AS konum_var,
       count(*) FILTER (WHERE z.lat IS NOT NULL AND mu.lat IS NOT NULL) AS mesafe_olculebilir,
       count(*) FILTER (WHERE z.lat IS NOT NULL AND mu.lat IS NULL)     AS musteri_konumu_yok
  FROM saha_ziyaret z
  LEFT JOIN saha_musteri mu ON mu.id = z.musteri_id
 WHERE z.rep_id = 'ae0c55f9-68cc-421d-96d9-409222452f1a'
   AND z.ziyaret_tarihi >= current_date - 2;"
echo "  ⚠ 'musteri_konumu_yok' buyukse: check-in kaydediliyor ama KARSILASTIRILACAK"
echo "     bir referans yok. Yani konum toplaniyor, ise yaramiyor."
