#!/usr/bin/env bash
# DENETIM_112F — segment turetmeyi kur. DOGRULAMA KAPISI ONCE.
#
# Sozluk: BINEK / HAFIF_TICARI / KAMYON_OTOBUS.
# Kurallar (sunucunun kendi mantigindan):
#   KAMYON_OTOBUS: yarim-inc jant (17.5/19.5/22.5) — binek asla degil; ya da kamyon/otobüs/tır/çeker/dorse
#   HAFIF_TICARI : R\d{2}C sonekli ebat (195R14C); ya da kamyonet/minibüs/panelvan
#   BINEK        : geri kalan
#
# ⚠ KAPI: turetmeyi ETIKETLI (11-12 Tem) satirlara uygula, gercek etiketle kiyasla.
#   Uyum %95'in altindaysa DUR — kuralim yanlis demektir, boslari bozmam.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

# ─── TEK KAYNAK: CASE ifadesi (hem dogrulama hem backfill hem cron ayni mantik) ───
read -r -d '' SEG_CASE <<'SQL' || true
CASE
  WHEN cap IN (17.5,19.5,22.5) THEN 'KAMYON_OTOBUS'
  WHEN coalesce(model,'') ~* '\y(kamyon|otobus|otobüs|tir|çeker|ceker|dorse|römork|romork|treyler)\y' THEN 'KAMYON_OTOBUS'
  WHEN coalesce(ebat,'')  ~* 'R[0-9]{2}C\M' OR coalesce(model,'') ~* 'R[0-9]{2}C\M' THEN 'HAFIF_TICARI'
  WHEN coalesce(model,'') ~* '\y(kamyonet|minibüs|minibus|panelvan)\y' THEN 'HAFIF_TICARI'
  ELSE 'BINEK'
END
SQL

echo "############ 1) ⚠ DOGRULAMA KAPISI — etiketli satirlarda turetme = gercek mi? ############"
$PSQL -c "
WITH d AS (
  SELECT segment AS gercek, ($SEG_CASE) AS turetilen
    FROM bi_rakip_fiyat WHERE segment IS NOT NULL AND segment<>''
)
SELECT gercek, turetilen, count(*) FROM d
 GROUP BY 1,2 ORDER BY count(*) DESC;"

UYUM=$($PSQL -tAc "
WITH d AS (
  SELECT segment AS gercek, ($SEG_CASE) AS turetilen
    FROM bi_rakip_fiyat WHERE segment IS NOT NULL AND segment<>''
)
SELECT round(100.0*count(*) FILTER (WHERE gercek=turetilen)/count(*),1) FROM d;" | tr -d '[:space:]')
echo "  ⚠ UYUM: %$UYUM  (>=95 olmali)"
# kapi
awk "BEGIN{exit !($UYUM >= 95)}" || { echo "  ⛔ UYUM DUSUK — kural yanlis. Boslari BOZMUYORUM. Kurali gozden gecir."; exit 1; }
echo "  ✅ kapi gecti — turetme etiketli veriyle >=%95 uyusuyor"

echo
echo "############ 2) BACKFILL — sadece BOS segment (etiketli satirlara DOKUNMA) ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL || exit 1
UPDATE bi_rakip_fiyat
   SET segment = ($SEG_CASE)
 WHERE segment IS NULL OR segment = '';
SQL
echo "  ✅ bos segmentler dolduruldu"

echo
echo "############ 3) SONUC — 13-14 Tem artik segmentli mi? ############"
$PSQL -c "
SELECT scraped_at::date, count(*) satir,
       count(*) FILTER (WHERE segment IS NOT NULL AND segment<>'') dolu,
       count(*) FILTER (WHERE segment='KAMYON_OTOBUS') kamyon,
       count(*) FILTER (WHERE segment='HAFIF_TICARI') hafif
  FROM bi_rakip_fiyat WHERE scraped_at::date>='2026-07-13'
 GROUP BY 1 ORDER BY 1 DESC;"

echo
echo "############ 4) KALICI: derive_segment.sql + cron (bir daha sessizce durmasin) ############"
cat > /opt/price_monitor/sql/derive_segment.sql <<SQL
-- derive_segment.sql — her gun BOS segmentleri doldurur. Idempotent.
-- ⚠ Bu adim 13 Tem'de kayboldu (manuel siniflandirici cron'a bagli degildi).
--   Artik pipeline'in parcasi. Kurallar server_container ile ayni.
UPDATE bi_rakip_fiyat
   SET segment = ($SEG_CASE)
 WHERE segment IS NULL OR segment = '';

-- ⚠ KAPI: son 2 gunun lastik satirlarinda segment-bos orani yuksekse BAGIR.
DO \$\$
DECLARE _bos_pct numeric;
BEGIN
  SELECT round(100.0*count(*) FILTER (WHERE segment IS NULL OR segment='')/nullif(count(*),0),1)
    INTO _bos_pct
    FROM bi_rakip_fiyat
   WHERE scraped_at > now() - interval '2 days';
  IF _bos_pct > 5 THEN
    RAISE WARNING '[segment] ⚠ SON 2 GUN segment-bos oran %%: %%. Turetme calismiyor olabilir.', _bos_pct;
  ELSE
    RAISE NOTICE '[segment] ok — bos oran %%: %%', _bos_pct;
  END IF;
END \$\$;
SQL
echo "  ✅ /opt/price_monitor/sql/derive_segment.sql yazildi"

# cron: sm_classify (07:05) SONRASI 07:08 — idempotent ekleme
CRON_LINE='8 7 * * * docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < /opt/price_monitor/sql/derive_segment.sql >> /var/log/segment_derive.log 2>&1'
if crontab -l 2>/dev/null | grep -qF 'derive_segment.sql'; then
  echo "  ⏭ cron zaten var"
else
  ( crontab -l 2>/dev/null; echo "# Segment turetme — her gun 07:08 (SEGMENT_DERIVE_V1)"; echo "$CRON_LINE" ) | crontab -
  echo "  ✅ cron eklendi (07:08)"
fi
echo "  --- cron dogrula ---"
crontab -l | grep -A1 'SEGMENT_DERIVE_V1\|derive_segment' | sed 's/^/    /'

echo
echo "############ 5) ⚠ GUARD PROVA — derive_segment.sql simdi calisir mi? ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < /opt/price_monitor/sql/derive_segment.sql 2>&1 | sed 's/^/  /'

echo
echo "############ SONUC ############"
echo "  ✅ segment turetildi + backfill + cron + kapi. Bir daha sessizce durmaz."
echo "  ⚠ Sunucunun segment IN (...) sorgulari artik taze satirlarda calisir (Brisa brifingi dahil)."
