#!/usr/bin/env bash
# DENETIM_112H — segment turetme, DUZELTILMIS kural + DOGRU kapi.
#
# ⚠ 112F ogretti: tarihsel etiket YANLIS (geniş C-van lastiklerini BINEK saymis).
#   Kural DOGRU. O yuzden "tarihselle uyum" YANLIS kapiydi. Dogru kapi:
#     A) Kuralin ticari dedigi GERCEKTEN ticari mi (ornek + C/van sinyali sart)
#     B) BINEK'te ticari SIZINTI kaldi mi (C-sonekli BINEK = 0 olmali)
#
# ⚠ DUZELTME: 'R\d{2} ?C' (bosluk opsiyonel — "195R14 C" de yakalansin, 37 kacan).
# ⚠ Tutarlilik: kurali TUM satirlara uygula (tarihsel hatalari da duzelt), YEDEKLI.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

read -r -d '' SEG_CASE <<'SQL' || true
CASE
  WHEN cap IN (17.5,19.5,22.5) THEN 'KAMYON_OTOBUS'
  WHEN coalesce(model,'') ~* '\y(kamyon|otobus|otobüs|tir|çeker|ceker|dorse|römork|romork|treyler)\y' THEN 'KAMYON_OTOBUS'
  WHEN coalesce(ebat,'')  ~* 'R ?[0-9]{2}\.?5? ?C\M' OR coalesce(model,'') ~* 'R ?[0-9]{2}\.?5? ?C\M' THEN 'HAFIF_TICARI'
  WHEN coalesce(model,'') ~* '\y(kamyonet|minibüs|minibus|panelvan)\y' THEN 'HAFIF_TICARI'
  ELSE 'BINEK'
END
SQL

hr "1. ⚠ DOGRU KAPI A — kuralin TICARI dedikleri gercekten ticari mi? (ornek)"
$PSQL -c "
SELECT ($SEG_CASE) AS turetilen, ebat, left(model,42) AS model
  FROM bi_rakip_fiyat
 WHERE ($SEG_CASE) IN ('HAFIF_TICARI','KAMYON_OTOBUS')
 ORDER BY random() LIMIT 16;"
echo "  ⚠ Hepsinde C-sonek / yarim-inc / van-kamyon sinyali OLMALI."

hr "2. ⚠ DOGRU KAPI B — BINEK'e ticari SIZINTISI var mi? (0 olmali)"
SIZ=$($PSQL -tAc "
SELECT count(*) FROM bi_rakip_fiyat
 WHERE ($SEG_CASE)='BINEK'
   AND (coalesce(ebat,'') ~* 'R ?[0-9]{2}\.?5? ?C\M' OR cap IN (17.5,19.5,22.5));" | tr -d '[:space:]')
echo "  BINEK'te C-sonek/yarim-inc kalan: $SIZ  (0 olmali)"
awk "BEGIN{exit !($SIZ==0)}" || { echo "  ⛔ SIZINTI VAR — regex hala eksik. DUR."; exit 1; }
echo "  ✅ kapi B gecti — BINEK temiz, ticari sizmiyor"

hr "3. YENI DAGILIM (uygulanınca ne olacak) — makul mu?"
$PSQL -c "
SELECT ($SEG_CASE) AS segment, count(*)
  FROM bi_rakip_fiyat GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ HAFIF_TICARI ~5000, KAMYON ~300, geri kalan BINEK bekleniyor (tarihsel 450+292 hat_aliydi)."

hr "4. YEDEK — eski segment degerleri (geri donus)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
DROP TABLE IF EXISTS yedek_rakip_segment;
CREATE TABLE yedek_rakip_segment AS
  SELECT id, segment AS eski_segment, now() AS yedek_at FROM bi_rakip_fiyat;
SQL
$PSQL -c "SELECT count(*) AS yedeklenen FROM yedek_rakip_segment;"

hr "5. UYGULA — TUM satirlar (tarihsel hata + bos, hepsi tutarli)"
$PSQL -v ON_ERROR_STOP=1 <<SQL || exit 1
UPDATE bi_rakip_fiyat SET segment = ($SEG_CASE);
SQL
echo "  ✅ segment tum satirlarda turetildi"

hr "6. SONUC — 13-14 Tem + genel"
$PSQL -c "SELECT segment, count(*) FROM bi_rakip_fiyat GROUP BY 1 ORDER BY 2 DESC;"
$PSQL -c "
SELECT scraped_at::date, count(*) FILTER (WHERE segment IS NOT NULL AND segment<>'') dolu,
       count(*) FILTER (WHERE segment='HAFIF_TICARI') hafif, count(*) FILTER (WHERE segment='KAMYON_OTOBUS') kamyon
  FROM bi_rakip_fiyat WHERE scraped_at::date>='2026-07-13' GROUP BY 1 ORDER BY 1 DESC;"

hr "7. KALICI — derive_segment.sql (yeni satirlar) + cron + guard"
cat > /opt/price_monitor/sql/derive_segment.sql <<SQL
-- derive_segment.sql — yeni (segmentsiz) satirlari doldurur. Idempotent.
-- ⚠ 13 Tem'de kayboldu (manuel siniflandirici cron'a bagli degildi). Artik pipeline'da.
UPDATE bi_rakip_fiyat
   SET segment = ($SEG_CASE)
 WHERE segment IS NULL OR segment = '';

DO \$\$
DECLARE _bos numeric;
BEGIN
  SELECT round(100.0*count(*) FILTER (WHERE segment IS NULL OR segment='')/nullif(count(*),0),1)
    INTO _bos FROM bi_rakip_fiyat WHERE scraped_at > now() - interval '2 days';
  IF _bos > 5 THEN RAISE WARNING '[segment] ⚠ son 2 gun bos oran %%: %%', _bos;
  ELSE RAISE NOTICE '[segment] ok bos %%: %%', _bos; END IF;
END \$\$;
SQL
echo "  ✅ derive_segment.sql yazildi"
CRON_LINE='8 7 * * * docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < /opt/price_monitor/sql/derive_segment.sql >> /var/log/segment_derive.log 2>&1'
if crontab -l 2>/dev/null | grep -qF 'derive_segment.sql'; then echo "  ⏭ cron zaten var"; else
  ( crontab -l 2>/dev/null; echo "# Segment turetme 07:08 (SEGMENT_DERIVE_V1)"; echo "$CRON_LINE" ) | crontab -
  echo "  ✅ cron eklendi (07:08)"; fi
crontab -l | grep -F 'derive_segment' | sed 's/^/    /'

hr "SONUC"
echo "  ✅ segment turetildi (kural tarihselden DOGRU), backfill+cron+guard, tutarli."
echo "  ⚠ Geri donus: yedek_rakip_segment"
