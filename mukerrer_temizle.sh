#!/usr/bin/env bash
# MUKERRER_TEMIZLE — SADECE notlari BIREBIR AYNI olanlar silinir.
#
# ⚠ NEDEN "en uzun notu tut" KURALINI GERI CEKTIM:
#   KALYON {1376, 118} · GEMPORT {613, 2081} · AKCANSA {595, 547} · ADM BETON {301, 106}
#   Bunlarin notlari FARKLI. "En uzun kalsin" deseydim GEMPORT'ta 613 karakterlik,
#   KALYON'da 118 karakterlik GERCEK ziyaret notunu silecektim.
#   Farkli icerik = ya iki ayri ziyaret, ya bolunmus bir kayit. BILMIYORUM.
#   Bilmedigim veriyi SILMEM.
#
# ✅ SILINEN: sadece notlari BIREBIR AYNI olanlar (cift tiklama urunu).
#    Ayni icerik -> biri gidince HICBIR SEY kaybolmaz.
#
# ⚠ SILMEDEN ONCE YEDEK. Silinen veri geri gelmez; yedek gelir.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ADAYLAR — notlari BIREBIR AYNI olan gruplar ############"
$PSQL -c "
WITH grup AS (
  SELECT rep_id, musteri_id, ziyaret_tarihi,
         count(*) AS adet,
         count(DISTINCT COALESCE(notlar,'')) AS farkli_not,
         array_agg(id ORDER BY created_at) AS ids
    FROM saha_ziyaret
   GROUP BY 1,2,3 HAVING count(*) > 1
)
SELECT m.firma, COALESCE(u.full_name,'(import)') AS rep, g.ziyaret_tarihi,
       g.adet, g.farkli_not,
       CASE WHEN g.farkli_not = 1 THEN '✅ SILINECEK (icerik ayni)'
            ELSE '⛔ DOKUNULMAYACAK (icerik farkli)' END AS karar
  FROM grup g
  JOIN saha_musteri m ON m.id = g.musteri_id
  LEFT JOIN users u ON u.id = g.rep_id
 ORDER BY g.farkli_not, g.ziyaret_tarihi DESC;"

echo
echo "############ 2) ⚠ SILINECEK KAYIT SAYISI ############"
$PSQL -c "
WITH grup AS (
  SELECT rep_id, musteri_id, ziyaret_tarihi, count(*) AS adet,
         count(DISTINCT COALESCE(notlar,'')) AS farkli_not
    FROM saha_ziyaret GROUP BY 1,2,3 HAVING count(*) > 1
)
SELECT count(*) FILTER (WHERE farkli_not = 1)  AS silinecek_grup,
       sum(adet - 1) FILTER (WHERE farkli_not = 1) AS silinecek_kayit,
       count(*) FILTER (WHERE farkli_not > 1)  AS dokunulmayacak_grup,
       sum(adet - 1) FILTER (WHERE farkli_not > 1) AS incelenecek_kayit
  FROM grup;"

echo
echo "############ 3) YEDEK — silmeden once ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || { echo "❌ YEDEK ALINAMADI — SILME YOK"; exit 1; }
DROP TABLE IF EXISTS saha_ziyaret_mukerrer_yedek;
CREATE TABLE saha_ziyaret_mukerrer_yedek AS
WITH grup AS (
  SELECT rep_id, musteri_id, ziyaret_tarihi,
         count(DISTINCT COALESCE(notlar,'')) AS farkli_not
    FROM saha_ziyaret GROUP BY 1,2,3 HAVING count(*) > 1
),
silinecek AS (
  SELECT z.id
    FROM saha_ziyaret z
    JOIN grup g ON g.rep_id IS NOT DISTINCT FROM z.rep_id
               AND g.musteri_id = z.musteri_id
               AND g.ziyaret_tarihi IS NOT DISTINCT FROM z.ziyaret_tarihi
   WHERE g.farkli_not = 1
     AND z.id <> (
       SELECT z2.id FROM saha_ziyaret z2
        WHERE z2.rep_id IS NOT DISTINCT FROM z.rep_id
          AND z2.musteri_id = z.musteri_id
          AND z2.ziyaret_tarihi IS NOT DISTINCT FROM z.ziyaret_tarihi
        ORDER BY z2.created_at ASC LIMIT 1)   -- ⚠ ILK olusan KALIR
)
SELECT z.* FROM saha_ziyaret z JOIN silinecek s ON s.id = z.id;
SQL
$PSQL -c "SELECT count(*) AS yedeklenen FROM saha_ziyaret_mukerrer_yedek;"

echo
echo "############ 4) ⚠ BAGLI KAYITLAR — foto/yorum var mi? ############"
$PSQL -c "
SELECT (SELECT count(*) FROM saha_ziyaret_foto f
         JOIN saha_ziyaret_mukerrer_yedek y ON y.id = f.ziyaret_id)   AS silinecekte_foto,
       (SELECT count(*) FROM saha_rakip_teklif t
         JOIN saha_ziyaret_mukerrer_yedek y ON y.id = t.ziyaret_id)   AS silinecekte_rakip_teklif;"
echo "  ⚠ Bagli kayit varsa: onlari KALAN ziyarete tasimaliyim, silmemeliyim."

echo
echo "############ 5) SIL ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || { echo "❌ SILME BASARISIZ"; exit 1; }
BEGIN;
-- ⚠ Bagli kayitlari KALAN ziyarete tasi (silme, TASI)
UPDATE saha_ziyaret_foto f
   SET ziyaret_id = (
     SELECT z2.id FROM saha_ziyaret z2
       JOIN saha_ziyaret_mukerrer_yedek y ON y.id = f.ziyaret_id
      WHERE z2.rep_id IS NOT DISTINCT FROM y.rep_id
        AND z2.musteri_id = y.musteri_id
        AND z2.ziyaret_tarihi IS NOT DISTINCT FROM y.ziyaret_tarihi
        AND z2.id <> y.id
      ORDER BY z2.created_at ASC LIMIT 1)
 WHERE f.ziyaret_id IN (SELECT id FROM saha_ziyaret_mukerrer_yedek);

UPDATE saha_rakip_teklif t
   SET ziyaret_id = (
     SELECT z2.id FROM saha_ziyaret z2
       JOIN saha_ziyaret_mukerrer_yedek y ON y.id = t.ziyaret_id
      WHERE z2.rep_id IS NOT DISTINCT FROM y.rep_id
        AND z2.musteri_id = y.musteri_id
        AND z2.ziyaret_tarihi IS NOT DISTINCT FROM y.ziyaret_tarihi
        AND z2.id <> y.id
      ORDER BY z2.created_at ASC LIMIT 1)
 WHERE t.ziyaret_id IN (SELECT id FROM saha_ziyaret_mukerrer_yedek);

DELETE FROM saha_ziyaret WHERE id IN (SELECT id FROM saha_ziyaret_mukerrer_yedek);
COMMIT;
SQL

echo
echo "############ 6) ⚠ DOGRULA ############"
$PSQL -c "
WITH grup AS (
  SELECT rep_id, musteri_id, ziyaret_tarihi, count(*) AS adet,
         count(DISTINCT COALESCE(notlar,'')) AS farkli_not
    FROM saha_ziyaret GROUP BY 1,2,3 HAVING count(*) > 1
)
SELECT count(*) FILTER (WHERE farkli_not = 1) AS kalan_ayni_icerikli,
       count(*) FILTER (WHERE farkli_not > 1) AS kalan_farkli_icerikli
  FROM grup;"
echo "  ⚠ 'kalan_ayni_icerikli' 0 olmali."
echo "  ⚠ 'kalan_farkli_icerikli' > 0 NORMAL — onlar bilerek birakildi, INCELENECEK."
$PSQL -c "SELECT count(*) AS toplam_ziyaret FROM saha_ziyaret;"
echo "  yedek: saha_ziyaret_mukerrer_yedek (geri donus icin duruyor)"

echo
echo "############ 7) INCELENECEKLER — farkli icerikli gruplar ############"
$PSQL -c "
WITH grup AS (
  SELECT rep_id, musteri_id, ziyaret_tarihi, count(*) AS adet,
         count(DISTINCT COALESCE(notlar,'')) AS farkli_not
    FROM saha_ziyaret GROUP BY 1,2,3 HAVING count(*) > 1
)
SELECT m.firma, COALESCE(u.full_name,'(import)') AS rep, g.ziyaret_tarihi, g.adet
  FROM grup g
  JOIN saha_musteri m ON m.id=g.musteri_id
  LEFT JOIN users u ON u.id=g.rep_id
 WHERE g.farkli_not > 1
 ORDER BY g.ziyaret_tarihi DESC;"
echo "  ⚠ Bunlar ayni gun IKI AYRI ZIYARET mi, yoksa bolunmus TEK kayit mi?"
echo "     Cevap sahada. Eftal/Huseyin'e sorulmali — ben karar veremem."
