#!/usr/bin/env bash
# Yüksek-değerli çekmeceleri incele (varsayım yok): kolon + kapsam + örnek. Taslak-tanım için. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }
incele(){
  local tbl="$1"
  hr "$tbl"
  echo "--- kolonlar ---"
  $PSQL -tA -c "SELECT string_agg(column_name||'('||data_type||')', ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='$tbl' AND table_schema='public';" 2>&1 | fold -s -w 150 | sed 's/^/  /'
  echo "--- satır sayısı ---"
  $PSQL -tA -c "SELECT count(*) FROM $tbl;" 2>&1 | sed 's/^/  /'
  echo "--- 2 örnek satır ---"
  $PSQL -x -c "SELECT * FROM $tbl LIMIT 2;" 2>&1 | head -60 | sed 's/^/  /'
}

incele bi_rakip_fiyat_gecmis
incele bi_pazar_fiyat
incele bi_odeme_gecmisi
incele saha_ziyaret
incele bi_marj_fact
incele bi_kacan_satislar

hr "BITTI — yapılarını gördüm; şimdi doğru taslak-tanımları yazarım."
