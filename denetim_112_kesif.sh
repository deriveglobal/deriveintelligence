#!/usr/bin/env bash
# DENETIM_112_KESIF — segment yazicisi neden 13 Tem'de durdu? SADECE OKUR.
#   Hipotez: 13 Tem ERP yuklemesi, segmenti siniflandiran bir tabloyu/lookup'i ezdi.
#   Once: segment NEREDE yaziliyor, NEYE bagli, 13 Tem'de ne degisti.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
SRC="server_container.mjs"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_rakip_fiyat.segment NEREDE yaziliyor? (server + scriptler)"
echo "--- server_container.mjs: bi_rakip_fiyat + segment ---"
grep -nE "bi_rakip_fiyat|segment" "$SRC" | grep -iE "rakip.*segment|segment.*rakip|INSERT INTO bi_rakip_fiyat|UPDATE bi_rakip_fiyat" | head -15 | sed 's/^/  /'
echo "--- diskteki scraper/scriptler bi_rakip_fiyat yaziyor mu? ---"
grep -rlnE "bi_rakip_fiyat" /opt/krb-assessment --include='*.py' --include='*.mjs' --include='*.js' --include='*.sh' \
  --exclude-dir=node_modules 2>/dev/null | grep -viE "server_container|\.bak" | sed 's/^/  /'

hr "2. segment'i SINIFLANDIRAN kod — ebat -> KAMYON/BINEK nasil?"
grep -rnE "KAMYON_OTOBUS|HAFIF_TICARI|BINEK|segment *=" /opt/krb-assessment --include='*.py' --include='*.mjs' \
  --exclude-dir=node_modules 2>/dev/null | grep -viE "\.bak|server_container" | head -20 | sed 's/^/  /'
echo "--- server icinde segment siniflandirmasi ---"
grep -nE "KAMYON_OTOBUS|HAFIF_TICARI|segment.*CASE|classify.*segment|segmentle" "$SRC" | head -15 | sed 's/^/  /'

hr "3. segment bir LOOKUP'a mi bagli? (bi_urun_master.segment / segment tablosu)"
$PSQL -c "SELECT column_name, table_name FROM information_schema.columns
          WHERE column_name='segment' AND table_name NOT LIKE '%yedek%' ORDER BY table_name;"
echo "--- bi_urun_master.segment dolu mu (segment kaynagi olabilir)? ---"
$PSQL -c "SELECT count(*) toplam, count(*) FILTER (WHERE segment IS NOT NULL AND segment<>'') AS segmentli
          FROM bi_urun_master;" 2>&1 | sed 's/^/  /'

hr "4. 13 TEM'de NE DEGISTI? — o gece hangi ERP yuklemeleri oldu"
$PSQL -c "SELECT query_type, processed_at, row_count_kept||'/'||row_count_raw AS satir
          FROM bi_ingestion_log
          WHERE processed_at::date BETWEEN '2026-07-12' AND '2026-07-14'
          ORDER BY processed_at;" 2>&1 | sed 's/^/  /'

hr "5. SCRAPER CRON — segment adimini calistiran bir sey durdu mu?"
crontab -l 2>/dev/null | grep -iE "rakip|scrape|segment|fiyat" | sed 's/^/  /' || echo "  (root crontab bos/yok)"
ls -la /etc/cron.d/ 2>/dev/null | grep -iE "rakip|scrape|krb" | sed 's/^/  /' || true
echo "--- scraper log son satirlar (varsa) ---"
find /opt/krb-assessment /var/log -maxdepth 2 -iname '*scrape*' -o -iname '*rakip*log*' 2>/dev/null | head | sed 's/^/  /'

hr "6. segment: taze satirlarda GERCEKTEN bos mu, ebat dolu mu? (siniflandirma girdisi var mi)"
$PSQL -c "
SELECT scraped_at::date, count(*) AS satir,
       count(*) FILTER (WHERE ebat IS NOT NULL AND ebat<>'') AS ebat_dolu,
       count(*) FILTER (WHERE segment IS NOT NULL AND segment<>'') AS segment_dolu
  FROM bi_rakip_fiyat
 WHERE scraped_at::date BETWEEN '2026-07-11' AND '2026-07-14'
 GROUP BY 1 ORDER BY 1 DESC;" 2>&1 | sed 's/^/  /'
echo "  ⚠ ebat dolu ama segment bos ise: siniflandirici girdisi VAR, kendisi calismiyor demektir."

hr "BITTI — kok sebep bu ciktidan cikacak"
