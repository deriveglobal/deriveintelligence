#!/usr/bin/env bash
# DENETIM_112D — segment'i ESKIDEN ne yaziyordu, yeni sm_* karsiligi var mi? OKUR.
set -uo pipefail
D=/opt/price_monitor
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. 'segment' YAZAN kod — TUM dosyalar (.py + .bak + git)"
grep -rnE "segment" "$D" --include='*.py' --include='*.py.bak*' 2>/dev/null \
  | grep -iE "UPDATE|SET segment|segment *=|'KAMYON|'HAFIF|'BINEK|'TICARI|'TUKETICI|ALTER.*segment" | head -30 | sed 's/^/  /'

hr "2. sm_normalize.py — cmd_backfill TAM govde (hangi kolonlari yaziyor)"
sed -n '169,215p' "$D/sm_normalize.py" | nl -ba -v169 | sed 's/^/  /'

hr "3. ESKI sm_normalize (.bak_ticari) segment yaziyor muydu?"
if [ -f "$D/sm_normalize.py.bak_ticari" ]; then
  grep -nE "segment|KAMYON|HAFIF_TICARI|BINEK|TUKETICI|UPDATE bi_rakip" "$D/sm_normalize.py.bak_ticari" | head -30 | sed 's/^/  /'
else echo "  (bak_ticari yok)"; fi

hr "4. GIT — 'segment' yazma NE ZAMAN kaldirildi?"
cd "$D" 2>/dev/null && {
  git log --oneline -S "segment" -- sm_normalize.py 2>/dev/null | head | sed 's/^/  /'
  echo "  --- 12 Tem civari commit'ler ---"
  git log --oneline --since='2026-07-11 20:00' --until='2026-07-12 06:00' 2>/dev/null | sed 's/^/  /'
}

hr "5. sm_master.py — bi_urun_master'a segment / arac_tipi yaziyor mu?"
grep -nE "segment|arac_tipi|KAMYON|HAFIF_TICARI|BINEK|TICARI|TUKETICI" "$D/sm_master.py" 2>/dev/null | head -20 | sed 's/^/  /'

hr "6. YENI KOLONLAR segment KARSILIGI tasiyor mu? (sm_desen/sm_yuk_hiz dolu satirlarda ne var)"
$PSQL -c "
SELECT
  count(*) AS satir_14tem,
  count(*) FILTER (WHERE sm_yuk_hiz IS NOT NULL AND sm_yuk_hiz<>'') AS yuk_hiz_dolu,
  count(*) FILTER (WHERE sm_desen  IS NOT NULL AND sm_desen<>'')  AS desen_dolu,
  count(*) FILTER (WHERE lastik_mi IS NOT NULL) AS lastik_mi_dolu,
  count(*) FILTER (WHERE ebat ~ 'C\b' OR ebat ILIKE '%C') AS ebat_C_ticari
  FROM bi_rakip_fiyat WHERE scraped_at::date='2026-07-14';" 2>&1 | sed 's/^/  /'
echo "  --- ornek: yeni satirda ebat + sm_yuk_hiz + segment (segment bos olmali) ---"
$PSQL -c "
SELECT ebat, sm_yuk_hiz, segment, left(model,40) AS model
  FROM bi_rakip_fiyat WHERE scraped_at::date='2026-07-14'
  AND ebat IS NOT NULL ORDER BY random() LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "BITTI"
echo "  ⚠ Karar: (a) sm_normalize segment'i de yazsin (koprü) — sunucu okumaya devam eder, ya da"
echo "     (b) sunucu sm_yuk_hiz/ebat-C'den segment turetsin. Hangisi daha az yerde degisiklik?"
