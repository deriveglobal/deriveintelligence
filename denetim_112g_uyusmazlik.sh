#!/usr/bin/env bash
# DENETIM_112G — kapinin durdurdugu 4448 uyusmazligi INCELE. SADECE OKUR.
#   Soru: benim C-kuralim binek'te yanlis mi yakaliyor, yoksa tarihsel yanlis mi etiketlemis?
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

read -r -d '' SEG_CASE <<'SQL' || true
CASE
  WHEN cap IN (17.5,19.5,22.5) THEN 'KAMYON_OTOBUS'
  WHEN coalesce(model,'') ~* '\y(kamyon|otobus|otobüs|tir|çeker|ceker|dorse|römork|romork|treyler)\y' THEN 'KAMYON_OTOBUS'
  WHEN coalesce(ebat,'')  ~* 'R[0-9]{2}C\M' OR coalesce(model,'') ~* 'R[0-9]{2}C\M' THEN 'HAFIF_TICARI'
  WHEN coalesce(model,'') ~* '\y(kamyonet|minibüs|minibus|panelvan)\y' THEN 'HAFIF_TICARI'
  ELSE 'BINEK'
END
SQL

hr "1. 4448: gercek=BINEK, turetilen=HAFIF_TICARI — NE bunlar? (ornekler)"
$PSQL -c "
WITH d AS (
  SELECT ebat, model, cap, segment AS gercek, ($SEG_CASE) AS turetilen
    FROM bi_rakip_fiyat WHERE segment IS NOT NULL AND segment<>''
)
SELECT ebat, left(model,50) AS model FROM d
 WHERE gercek='BINEK' AND turetilen='HAFIF_TICARI'
 ORDER BY random() LIMIT 20;"

hr "2. Bu 4448'i HANGI kural yakaliyor? ebat-C mi, model-C mi, kelime mi?"
$PSQL -c "
WITH d AS (
  SELECT ebat, model, segment AS gercek
    FROM bi_rakip_fiyat WHERE segment IS NOT NULL AND segment<>''
)
SELECT
  count(*) FILTER (WHERE coalesce(ebat,'')  ~* 'R[0-9]{2}C\M')  AS ebat_C,
  count(*) FILTER (WHERE coalesce(model,'') ~* 'R[0-9]{2}C\M')  AS model_C,
  count(*) FILTER (WHERE coalesce(model,'') ~* '\y(kamyonet|minibüs|minibus|panelvan)\y') AS kelime
  FROM d WHERE gercek='BINEK';"
echo "  ⚠ Hangisi buyukse, yanlis yakalayan o kural."

hr "3. ebat'ta C GERCEKTEN ticari mi? — ebat-C olan binek ornekleri"
$PSQL -c "
SELECT ebat, left(model,45) AS model, count(*) OVER() AS toplam
  FROM bi_rakip_fiyat
 WHERE segment='BINEK' AND coalesce(ebat,'') ~* 'R[0-9]{2}C\M'
 ORDER BY random() LIMIT 12;"

hr "4. GERCEK HAFIF_TICARI neye benziyor? (tarihsel dogru etiketler)"
$PSQL -c "
SELECT ebat, left(model,50) AS model
  FROM bi_rakip_fiyat WHERE segment='HAFIF_TICARI'
 ORDER BY random() LIMIT 15;"

hr "5. 37 KACIRILAN: gercek=HAFIF_TICARI ama turetilen=BINEK — ne kacirdim?"
$PSQL -c "
WITH d AS (
  SELECT ebat, model, cap, segment AS gercek, ($SEG_CASE) AS turetilen
    FROM bi_rakip_fiyat WHERE segment IS NOT NULL AND segment<>''
)
SELECT ebat, left(model,50) AS model FROM d
 WHERE gercek='HAFIF_TICARI' AND turetilen='BINEK' LIMIT 15;"

hr "BITTI"
echo "  ⚠ Ders: tarihsel etiket, C-sonekli binek lastiklerini BINEK saymis olabilir"
echo "     ( or. XL/RunFlat 'C' degil). Kurali daralt ya da tarihseli duzelt — cikti soyleyecek."
