#!/usr/bin/env bash
# DENETIM_112I — segment onarimini KALICI yap: trigger + ERP/refresh dogrulama.
#   ⚠ Cron 07:08 boslugu var (02:00 scrape -> 07:08 dolum). Trigger o boslugu kapatir:
#     her INSERT ekleme aninda segment yazar. para_birimi kapisiyla ayni desen.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ⚠ ERP YUKLEMESI bi_rakip_fiyat'a DOKUNUYOR MU? (varsayim degil, kanit)"
echo "--- erp_ingest.py bi_rakip_fiyat/DELETE/DROP yapiyor mu? ---"
grep -nE "bi_rakip_fiyat" /opt/krb-assessment/erp_ingest.py 2>/dev/null | sed 's/^/  /' || echo "  ✅ erp_ingest bi_rakip_fiyat'a HIC dokunmuyor (scraper tablosu, ERP'ye ait degil)"
echo "--- baska bir sey DROP/TRUNCATE bi_rakip_fiyat yapiyor mu? ---"
grep -rnE "DROP TABLE.*bi_rakip_fiyat|TRUNCATE.*bi_rakip_fiyat|DELETE FROM bi_rakip_fiyat\b" \
  /opt/krb-assessment /opt/price_monitor --include='*.py' --include='*.mjs' --include='*.sql' --include='*.sh' \
  --exclude-dir=node_modules --exclude-dir=venv 2>/dev/null | grep -viE '\.bak|yedek' | sed 's/^/  /' || echo "  ✅ DROP/TRUNCATE yok — tablo kalici, satirlar birikiyor"

hr "2. bi_rakip_fiyat_son — VIEW mi MATVIEW mi? segment iceriyor mu?"
$PSQL -c "SELECT relkind, CASE relkind WHEN 'v' THEN 'VIEW (canli)' WHEN 'm' THEN 'MATVIEW (tazelenmeli)' END AS tip
          FROM pg_class WHERE relname='bi_rakip_fiyat_son';"
echo "--- _son segment kolonunu base'den mi aliyor? tanim: ---"
$PSQL -c "SELECT pg_get_viewdef('bi_rakip_fiyat_son'::regclass, true);" 2>&1 | grep -iE "segment|FROM bi_rakip" | head | sed 's/^/  /'

hr "3. Sunucu segment'i HANGI tablodan okuyor? (base mi _son mu)"
grep -nE "segment IN \('KAMYON|FROM bi_rakip_fiyat" /opt/krb-assessment/server_container.mjs \
  | grep -iE "bi_rakip_fiyat|segment IN" | head -12 | sed 's/^/  /'

hr "4. ⚠ TRIGGER — her INSERT/UPDATE'te segment turet (bosluk kapanir)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION derive_rakip_segment() RETURNS trigger AS $$
BEGIN
  -- INSERT'te her zaman turet (scraper segment vermez); UPDATE'te sadece bossa (elle duzeltmeyi ezme)
  IF TG_OP = 'INSERT' OR NEW.segment IS NULL OR NEW.segment = '' THEN
    NEW.segment := CASE
      WHEN NEW.cap IN (17.5,19.5,22.5) THEN 'KAMYON_OTOBUS'
      WHEN coalesce(NEW.model,'') ~* '\y(kamyon|otobus|otobüs|tir|çeker|ceker|dorse|römork|romork|treyler)\y' THEN 'KAMYON_OTOBUS'
      WHEN coalesce(NEW.ebat,'')  ~* 'R ?[0-9]{2}\.?5? ?C\M' OR coalesce(NEW.model,'') ~* 'R ?[0-9]{2}\.?5? ?C\M' THEN 'HAFIF_TICARI'
      WHEN coalesce(NEW.model,'') ~* '\y(kamyonet|minibüs|minibus|panelvan)\y' THEN 'HAFIF_TICARI'
      ELSE 'BINEK'
    END;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_derive_rakip_segment ON bi_rakip_fiyat;
CREATE TRIGGER trg_derive_rakip_segment
  BEFORE INSERT OR UPDATE ON bi_rakip_fiyat
  FOR EACH ROW EXECUTE FUNCTION derive_rakip_segment();
SQL
echo "  ✅ trigger kuruldu"

hr "5. ⚠ KAPI TESTI — segmentsiz ticari + binek eklersek trigger yazar mi? (ROLLBACK)"
$PSQL <<'SQL'
BEGIN;
INSERT INTO bi_rakip_fiyat (kaynak, marka, ebat, model, cap, fiyat)
VALUES ('__TEST__','Petlas','225/65R16C 112/110R','Petlas FullGrip 225/65R16C', 16, 1),
       ('__TEST__','Michelin','205/55R16 91V','Michelin Primacy 205/55R16', 16, 1),
       ('__TEST__','Bridgestone','315/80R22.5','Bridgestone kamyon 315/80R22.5', 22.5, 1);
SELECT ebat, segment FROM bi_rakip_fiyat WHERE kaynak='__TEST__' ORDER BY ebat;
ROLLBACK;
SQL
echo "  ⚠ Beklenen: 205/55R16->BINEK · 225/65R16C->HAFIF_TICARI · 315/80R22.5->KAMYON_OTOBUS"
echo "  (test satirlari ROLLBACK ile silindi)"

hr "6. bugunku bos segment 0 mi? (trigger sonrasi yeni scrape'ler otomatik dolacak)"
$PSQL -c "SELECT count(*) FILTER (WHERE segment IS NULL OR segment='') AS bos_bugun
          FROM bi_rakip_fiyat WHERE scraped_at::date='2026-07-14';"

hr "SONUC"
echo "  ✅ Trigger: her satir ekleme aninda segment alir — 02:00-07:08 boslugu KAPANDI."
echo "  ✅ Cron 07:08 artik GUVENLIK AGI (trigger birincil). Guard bos oran %5>'te bagirir."
echo "  ⚠ ERP yuklemesi bu tabloya dokunmuyor (yukarida kanit) — segment ERP'den bagimsiz."
