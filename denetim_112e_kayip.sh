#!/usr/bin/env bash
# DENETIM_112E — kayip segment siniflandiricisini bul + tarihsel sozlugu gor. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TARIHSEL segment SOZLUGU — 11-12 Tem'de hangi degerler yazilmisti?"
$PSQL -c "
SELECT segment, count(*) FROM bi_rakip_fiyat
 WHERE segment IS NOT NULL AND segment<>''
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Turetme BU degerleri uretmeli — sunucu bunlari okuyor."

hr "2. KAYIP SINIFLANDIRICI — KAMYON_OTOBUS yazan kod NEREDE? (tum /opt, sql dahil)"
grep -rlnE "KAMYON_OTOBUS|'HAFIF_TICARI'|segment *= *'|SET segment" /opt 2>/dev/null \
  | grep -viE "venv|site-packages|node_modules|\.git/" | head -20 | sed 's/^/  /'

hr "3. sql/ ve migrations/ icinde segment UPDATE'i var mi?"
for d in /opt/price_monitor/sql /opt/price_monitor/migrations /opt/krb-assessment/sql; do
  [ -d "$d" ] && { echo "  --- $d ---"; grep -rlnE "segment|KAMYON|HAFIF_TICARI" "$d" 2>/dev/null | sed 's/^/    /'; }
done

hr "4. server_container.mjs — arac_tipi/segment TURETME mantigi (koprü icin kural kaynagi)"
grep -nE "KAMYON_EBAT|17\.5|19\.5|22\.5|R\\\\d\{2\}C|/R\\\\d|HAFIF_TICARI|arac_tipi *=" /opt/krb-assessment/server_container.mjs \
  | grep -iE "tip|segment|arac|C\\\\b|17.5|kamyon" | head -20 | sed 's/^/  /'

hr "5. TURETME SINYALI — ebat/yuk_hiz'den segment cikar mi? (canli deneme)"
$PSQL -c "
SELECT
  count(*) FILTER (WHERE cap IN (17.5,19.5,22.5)) AS yarim_inc_kamyon,
  count(*) FILTER (WHERE ebat ~* '[0-9]{2,3}/[0-9]{2,3}\s*[a-z].*[0-9]{2,3}[a-z]') AS cift_yuk,
  count(*) FILTER (WHERE ebat ~* 'C\M' OR model ~* '\yC\y|kamyonet|van|minibus') AS hafif_ticari_ipucu,
  count(*) FILTER (WHERE model ~* 'ceker|dorse|romork|kamyon|otobus|tir\M') AS kamyon_kelime,
  count(*) AS toplam
  FROM bi_rakip_fiyat WHERE scraped_at::date='2026-07-14';" 2>&1 | sed 's/^/  /'

hr "BITTI"
echo "  ⚠ 1) sozluk + 4) kurallar -> tek SQL turetme yazarim; cron'a baglarim; bos oran kapisi."
