#!/usr/bin/env bash
# SAHA_KONUM_2 — kolonlar checkin_lat / checkin_lng / checkin_at imis (lat/lng degil).
# ⚠ Yine kolon adini varsaydim, yine yanildim. Bu sefer semadan okudum.
# Sadece OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"

echo "############ 1) EFTAL — check-in'ler, koordinat + musteriye mesafe ############"
$PSQL -c "
SELECT to_char(z.ziyaret_tarihi,'DD Mon')                              AS tarih,
       to_char(z.checkin_at AT TIME ZONE 'Europe/Istanbul','HH24:MI')  AS checkin,
       left(mu.firma, 30)                                              AS musteri,
       z.checkin_lat, z.checkin_lng,
       mu.lat AS musteri_lat, mu.lng AS musteri_lng,
       CASE
         WHEN z.checkin_lat IS NULL            THEN 'check-in YOK'
         WHEN mu.lat IS NULL OR mu.lng IS NULL THEN '⚠ musteri konumu YOK -> olculemez'
         ELSE round((6371000 * acos(LEAST(1, GREATEST(-1,
                cos(radians(z.checkin_lat)) * cos(radians(mu.lat)) *
                cos(radians(mu.lng) - radians(z.checkin_lng)) +
                sin(radians(z.checkin_lat)) * sin(radians(mu.lat))
              ))))::numeric) || ' m'
       END AS mesafe
  FROM saha_ziyaret z
  LEFT JOIN saha_musteri mu ON mu.id = z.musteri_id
 WHERE z.rep_id = '$EFTAL' AND z.ziyaret_tarihi >= current_date - 2
 ORDER BY z.checkin_at NULLS LAST;"

echo
echo "############ 2) OZET — konum toplaniyor ama ISE YARIYOR mu? ############"
$PSQL -c "
SELECT count(*)                                                            AS ziyaret,
       count(z.checkin_lat)                                                AS checkin_var,
       count(*) FILTER (WHERE z.checkin_lat IS NOT NULL AND mu.lat IS NOT NULL) AS mesafe_olculebilir,
       count(*) FILTER (WHERE z.checkin_lat IS NOT NULL AND mu.lat IS NULL)     AS musteri_konumu_yok
  FROM saha_ziyaret z
  LEFT JOIN saha_musteri mu ON mu.id = z.musteri_id
 WHERE z.rep_id = '$EFTAL' AND z.ziyaret_tarihi >= current_date - 2;"

echo
echo "############ 3) TUM SAHA — 1.028 musterinin kacinin konumu var? ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(lat) AS konumu_var,
       count(*) - count(lat) AS konumu_yok
  FROM saha_musteri WHERE aktif;"
$PSQL -c "
SELECT count(*) AS tum_ziyaret, count(checkin_lat) AS checkin_atilmis
  FROM saha_ziyaret;"
echo "  ⚠ 'konumu_yok' buyukse: check-in toplaniyor, KARSILASTIRILACAK REFERANS YOK."
echo "     Yani konum var, anlami yok. Ama ilk check-in musterinin konumu SAYILABILIR:"
echo "     temsilci zaten dukkanin onunde. Kimseden ekstra is istemeden referans olusur."
