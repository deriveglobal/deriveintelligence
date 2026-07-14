#!/usr/bin/env bash
# MUSTERI_TEMIZLIK — Eftal + Huseyin disindaki TUM musteriler silinir.
#
# ⚠ KARAR FATIH'IN: "we can delete all records except Huseyin and Eftal,
#   no need to spend time for correction"
#
# ⚠ VE DOGRU KARAR. Otomatik il duzeltmesi calistirsaydim 14 musteriyi
#   BURDUR'a tasiyordum: "Yesilova -> BURDUR" ciktı, kural dogru calisti,
#   ama o Yesilova Burdur'un ilcesi DEGIL — Kocaeli/Duzce hattinda bir mahalle.
#   Kural mukemmeldi, sonuc yanlis olacakti. Bu veri TEMIZLENECEK KADAR IYI DEGIL.
#
# ⚠ YEDEK ALINIYOR. "Geri donusu yok" dedigim yerde bile yedek alirim.
#   Kullanici icin gittiler; sistemde geri getirilebilirler.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) KIMLER KALACAK? ############"
$PSQL -c "
SELECT u.id, u.full_name, u.email,
       (SELECT count(*) FROM saha_musteri m WHERE m.sorumlu_rep = u.id AND m.aktif) AS musteri
  FROM users u
 WHERE u.full_name ILIKE '%eftal%' OR u.full_name ILIKE '%hüseyin%' OR u.full_name ILIKE '%huseyin%'
 ORDER BY 4 DESC;"
echo "  ⚠ Yukaridaki iki kisi KALACAK. Baskasi cikarsa DUR."

EFTAL=$($PSQL -tAc "SELECT id FROM users WHERE full_name ILIKE '%eftal%' LIMIT 1" | head -1 | tr -d '[:space:]')
HUSEYIN=$($PSQL -tAc "SELECT id FROM users WHERE full_name ILIKE '%hüseyin%' OR full_name ILIKE '%huseyin%' LIMIT 1" | head -1 | tr -d '[:space:]')
echo "  Eftal   : $EFTAL"
echo "  Hüseyin : $HUSEYIN"
[ -n "$EFTAL" ] && [ -n "$HUSEYIN" ] || { echo "  ❌ Kullanici bulunamadi — DURDUM."; exit 1; }

echo
echo "############ 2) ⚠ NE SILINECEK? — SAYIMLA ############"
$PSQL -c "
WITH kalan AS (
  SELECT id FROM saha_musteri
   WHERE tenant_id='$T' AND sorumlu_rep IN ('$EFTAL','$HUSEYIN')
),
gidecek AS (
  SELECT id FROM saha_musteri WHERE tenant_id='$T' AND id NOT IN (SELECT id FROM kalan)
)
SELECT (SELECT count(*) FROM saha_musteri WHERE tenant_id='$T')        AS toplam_musteri,
       (SELECT count(*) FROM kalan)                                     AS KALACAK,
       (SELECT count(*) FROM gidecek)                                   AS SILINECEK,
       (SELECT count(*) FROM saha_ziyaret z JOIN gidecek g ON g.id=z.musteri_id)         AS ziyaret,
       (SELECT count(*) FROM saha_ziyaret_foto f JOIN saha_ziyaret z ON z.id=f.ziyaret_id
                                                 JOIN gidecek g ON g.id=z.musteri_id)     AS foto,
       (SELECT count(*) FROM saha_teklif t JOIN gidecek g ON g.id=t.musteri_id)          AS teklif,
       (SELECT count(*) FROM saha_rakip_teklif r JOIN gidecek g ON g.id=r.musteri_id)    AS rakip_teklif,
       (SELECT count(*) FROM saha_musteri_lokasyon l JOIN gidecek g ON g.id=l.musteri_id) AS lokasyon,
       (SELECT count(*) FROM saha_eslestirme_oneri e JOIN gidecek g ON g.id=e.saha_musteri_id) AS eslestirme_oneri;"

echo
echo "  --- Silinecek musterilerin SORUMLUSU kim? ---"
$PSQL -c "
SELECT COALESCE(u.full_name,'(ATANMAMIS)') AS rep, count(*) AS musteri
  FROM saha_musteri m
  LEFT JOIN users u ON u.id = m.sorumlu_rep
 WHERE m.tenant_id='$T' AND (m.sorumlu_rep IS NULL OR m.sorumlu_rep NOT IN ('$EFTAL','$HUSEYIN'))
 GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 3) YEDEK ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL || { echo "❌ YEDEK ALINAMADI — SILME YOK"; exit 1; }
DROP TABLE IF EXISTS yedek_musteri, yedek_ziyaret, yedek_ziyaret_foto,
                     yedek_teklif, yedek_rakip_teklif, yedek_lokasyon, yedek_eslestirme;

CREATE TABLE yedek_musteri AS
  SELECT * FROM saha_musteri
   WHERE tenant_id='$T' AND (sorumlu_rep IS NULL OR sorumlu_rep NOT IN ('$EFTAL','$HUSEYIN'));

CREATE TABLE yedek_ziyaret AS
  SELECT z.* FROM saha_ziyaret z JOIN yedek_musteri y ON y.id = z.musteri_id;

CREATE TABLE yedek_ziyaret_foto AS
  SELECT f.* FROM saha_ziyaret_foto f JOIN yedek_ziyaret y ON y.id = f.ziyaret_id;

CREATE TABLE yedek_teklif AS
  SELECT t.* FROM saha_teklif t JOIN yedek_musteri y ON y.id = t.musteri_id;

CREATE TABLE yedek_rakip_teklif AS
  SELECT r.* FROM saha_rakip_teklif r JOIN yedek_musteri y ON y.id = r.musteri_id;

CREATE TABLE yedek_lokasyon AS
  SELECT l.* FROM saha_musteri_lokasyon l JOIN yedek_musteri y ON y.id = l.musteri_id;

CREATE TABLE yedek_eslestirme AS
  SELECT e.* FROM saha_eslestirme_oneri e JOIN yedek_musteri y ON y.id = e.saha_musteri_id;
SQL
$PSQL -c "
SELECT (SELECT count(*) FROM yedek_musteri)       AS musteri,
       (SELECT count(*) FROM yedek_ziyaret)       AS ziyaret,
       (SELECT count(*) FROM yedek_ziyaret_foto)  AS foto,
       (SELECT count(*) FROM yedek_teklif)        AS teklif,
       (SELECT count(*) FROM yedek_rakip_teklif)  AS rakip_teklif,
       (SELECT count(*) FROM yedek_lokasyon)      AS lokasyon,
       (SELECT count(*) FROM yedek_eslestirme)    AS eslestirme;"
echo "  ✅ yedek_* tablolari — geri donus icin duruyor"

echo
echo "############ 4) ⚠ SIL — FK sirasiyla ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL || { echo "❌ SILME BASARISIZ — geri alindi"; exit 1; }
BEGIN;
DELETE FROM saha_ziyaret_foto WHERE ziyaret_id IN (SELECT id FROM yedek_ziyaret);
DELETE FROM saha_rakip_teklif WHERE musteri_id IN (SELECT id FROM yedek_musteri);
DELETE FROM saha_teklif_kalem WHERE teklif_id IN (SELECT id FROM yedek_teklif);
DELETE FROM saha_teklif_log   WHERE teklif_id IN (SELECT id FROM yedek_teklif);
DELETE FROM saha_teklif       WHERE musteri_id IN (SELECT id FROM yedek_musteri);
DELETE FROM saha_ziyaret      WHERE musteri_id IN (SELECT id FROM yedek_musteri);
DELETE FROM saha_musteri_lokasyon   WHERE musteri_id IN (SELECT id FROM yedek_musteri);
DELETE FROM saha_eslestirme_oneri   WHERE saha_musteri_id IN (SELECT id FROM yedek_musteri);
DELETE FROM saha_musteri_tedarikci_destek WHERE musteri_id IN (SELECT id FROM yedek_musteri);
DELETE FROM saha_musteri      WHERE id IN (SELECT id FROM yedek_musteri);
COMMIT;
SQL
echo "  ✅ silindi"

echo
echo "############ 5) ⚠ DOGRULA ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE sorumlu_rep='$EFTAL')   AS eftal,
       count(*) FILTER (WHERE sorumlu_rep='$HUSEYIN') AS huseyin,
       count(*) FILTER (WHERE sorumlu_rep IS NULL OR sorumlu_rep NOT IN ('$EFTAL','$HUSEYIN')) AS BASKASI
  FROM saha_musteri WHERE tenant_id='$T';"
echo "  ⚠ 'BASKASI' 0 olmali."
$PSQL -c "SELECT count(*) AS ziyaret FROM saha_ziyaret;"
$PSQL -c "SELECT count(*) AS teklif FROM saha_teklif;"

echo
echo "############ 6) ⚠ IL/ILCE — kalan veri ne kadar temiz? ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il)))  AS il_gecerli,
       count(*) FILTER (WHERE m.il IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))) AS il_gecersiz,
       count(*) FILTER (WHERE m.ilce IS NULL OR trim(m.ilce)='') AS ilce_bos
  FROM saha_musteri m WHERE m.aktif;"
echo "  --- kalan gecersiz iller ---"
$PSQL -c "
SELECT m.il, count(*) FROM saha_musteri m
 WHERE m.aktif AND m.il IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Kalan az sayidaki bozukluk, acilir liste kurulunca ELDE duzeltilebilir."
echo "     Geri donus: yedek_musteri · yedek_ziyaret · yedek_teklif ..."
