#!/usr/bin/env bash
# IL_ILCE_3_ONAR — kural bazli duzeltme. BELIRSIZLERE DOKUNMUYORUM.
#
# ⚠ SILME IL/ILCE SORUNUNU COZMEDI: bozuk kayitlar Eftal ve Huseyin'in
#   KENDI musterileri. 273 aktif musterinin 122'sinde il gecersiz, 173'unde ilce bos.
#
# ✅ KURAL BAZLI (~101 kayit):
#   (A) IL alanina ILCE yazilmis -> resmi listede TEK ADAY varsa duzelt
#   (B) BIRLESIK yazim ("Il-Ilce") -> ayristir
#
# ⛔ BELIRSIZ (~27 kayit) — DOKUNMUYORUM, LISTELIYORUM:
#   Yesilova(14) · Karamursel-Golcuk(6) · Kurucesme(2) · Yarimca(2)
#   Derince-Korfez(2) · Yahya Kaptan(1)
#   ⚠ Otomatik kural "Yesilova -> BURDUR" diyordu. Kural dogru, sonuc YANLIS olacakti.
#     Kocaeli/Duzce hattinda bir mahalle. Bilmedigim veriyi UYDURMAM.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 0) YEDEK ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
DROP TABLE IF EXISTS yedek_il_ilce;
CREATE TABLE yedek_il_ilce AS
  SELECT id, firma, il, ilce, now() AS yedek_at FROM saha_musteri WHERE aktif;
SQL
$PSQL -c "SELECT count(*) AS yedeklenen FROM yedek_il_ilce;"

echo
echo "############ 1) BUYUK/KUCUK HARF — resmi yazima cevir ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE saha_musteri m
   SET il = r.il, updated_at = now()
  FROM (SELECT DISTINCT il FROM tr_ilce_ref) r
 WHERE m.aktif AND tr_norm(m.il) = tr_norm(r.il) AND m.il <> r.il;
SQL

$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE saha_musteri m
   SET ilce = r.ilce, updated_at = now()
  FROM tr_ilce_ref r
 WHERE m.aktif AND tr_norm(m.il) = tr_norm(r.il)
   AND tr_norm(m.ilce) = tr_norm(r.ilce) AND m.ilce <> r.ilce;
SQL
echo "  ✅ resmi yazim"

echo
echo "############ 2) KURAL A — il alanina ILCE yazilmis (TEK ADAY) ############"
$PSQL -c "
WITH aday AS (
  SELECT m.id, m.il AS eski_il,
         (SELECT r.il   FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il) LIMIT 1) AS yeni_il,
         (SELECT r.ilce FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il) LIMIT 1) AS yeni_ilce
    FROM saha_musteri m
   WHERE m.aktif AND m.il IS NOT NULL AND m.il NOT LIKE '%-%'
     AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
     AND (SELECT count(DISTINCT r.il) FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il)) = 1
     -- ⚠ YESILOVA HARIC: kural BURDUR diyor ama o Kocaeli/Duzce'de bir mahalle.
     AND tr_norm(m.il) <> tr_norm('Yeşilova')
)
SELECT eski_il, yeni_il, yeni_ilce, count(*) FROM aday GROUP BY 1,2,3 ORDER BY 4 DESC;"

$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE saha_musteri m
   SET il   = (SELECT r.il   FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il) LIMIT 1),
       ilce = COALESCE(NULLIF(trim(m.ilce),''),
                       (SELECT r.ilce FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il) LIMIT 1)),
       updated_at = now()
 WHERE m.aktif AND m.il IS NOT NULL AND m.il NOT LIKE '%-%'
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
   AND (SELECT count(DISTINCT r.il) FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il)) = 1
   AND tr_norm(m.il) <> tr_norm('Yeşilova');
SQL
echo "  ✅ kural A"

echo
echo "############ 3) KURAL B — BIRLESIK yazim ayristir ############"
# ⚠ Sadece parcalardan BIRI resmi IL, digeri o ilin ILCESI ise ayristir.
#   Belirsizler (Karamursel-Golcuk, Derince-Korfez) DISARIDA kalir.
$PSQL -c "
WITH p AS (
  SELECT m.id, m.il AS eski,
         trim(split_part(m.il,'-',1)) AS a,
         trim(split_part(m.il,'-',2)) AS b
    FROM saha_musteri m WHERE m.aktif AND m.il LIKE '%-%'
),
c AS (
  SELECT p.*,
         (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(p.a) LIMIT 1) AS a_il,
         (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(p.b) LIMIT 1) AS b_il
    FROM p
)
SELECT eski,
       CASE WHEN a_il IS NOT NULL THEN a_il WHEN b_il IS NOT NULL THEN b_il END AS yeni_il,
       CASE WHEN a_il IS NOT NULL THEN b    WHEN b_il IS NOT NULL THEN a    END AS yeni_ilce,
       count(*) AS musteri,
       CASE WHEN a_il IS NULL AND b_il IS NULL THEN '⛔ BELIRSIZ — dokunulmayacak' ELSE '✅ ayristirilacak' END AS karar
  FROM c GROUP BY 1,2,3,5 ORDER BY 4 DESC;"

$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
WITH p AS (
  SELECT m.id, trim(split_part(m.il,'-',1)) AS a, trim(split_part(m.il,'-',2)) AS b
    FROM saha_musteri m WHERE m.aktif AND m.il LIKE '%-%'
),
c AS (
  SELECT p.*,
         (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(p.a) LIMIT 1) AS a_il,
         (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(p.b) LIMIT 1) AS b_il
    FROM p
),
y AS (
  SELECT id,
         COALESCE(a_il, b_il) AS yeni_il,
         CASE WHEN a_il IS NOT NULL THEN b ELSE a END AS yeni_ilce_ham
    FROM c WHERE a_il IS NOT NULL OR b_il IS NOT NULL
)
UPDATE saha_musteri m
   SET il = y.yeni_il,
       -- ⚠ Ilce resmi listede varsa RESMI yazimini kullan; yoksa ham hali kalir
       ilce = COALESCE(
                (SELECT r.ilce FROM tr_ilce_ref r
                  WHERE tr_norm(r.il)=tr_norm(y.yeni_il) AND tr_norm(r.ilce)=tr_norm(y.yeni_ilce_ham) LIMIT 1),
                NULLIF(y.yeni_ilce_ham,'')),
       updated_at = now()
  FROM y WHERE m.id = y.id;
SQL
echo "  ✅ kural B"

echo
echo "############ 4) ⚠ SONUC ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il)))  AS il_gecerli,
       count(*) FILTER (WHERE m.il IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))) AS il_GECERSIZ,
       count(*) FILTER (WHERE m.ilce IS NULL OR trim(m.ilce)='') AS ilce_bos
  FROM saha_musteri m WHERE m.aktif;"
echo "  ⚠ ONCE: 151 gecerli · 122 gecersiz · 173 ilce bos"

echo
echo "############ 5) ⛔ EFTAL'E SORULACAKLAR — dokunmadim ############"
$PSQL -c "
SELECT m.il AS yazilan, count(*) AS musteri,
       string_agg(DISTINCT left(m.firma, 24), ' · ') AS ornek_firmalar
  FROM saha_musteri m
 WHERE m.aktif AND m.il IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
 GROUP BY 1 ORDER BY 2 DESC;"
echo
echo "  ⚠ Bunlar mahalle/belde adi olabilir. Otomatik kural 'Yeşilova -> BURDUR' diyordu;"
echo "     kural dogruydu, SONUC YANLIS olacakti. Bilmedigim veriyi uydurmam."
echo "  ⚠ Geri donus: yedek_il_ilce"
