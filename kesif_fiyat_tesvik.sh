#!/usr/bin/env bash
# FİYAT LİSTESİ + TEŞVİK çekmeceleri — neyimiz var (satış listesi, satış primi, TEDARİKÇİ primi). OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }
say(){
  local tbl="$1"
  echo "--- $tbl ---"
  $PSQL -tA -c "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='$tbl' AND table_schema='public';" 2>&1 | fold -s -w 140 | sed 's/^/    /'
  $PSQL -tA -c "SELECT 'satır: '||count(*) FROM $tbl;" 2>&1 | sed 's/^/    /'
}

hr "1. TEŞVİK/PRİM/İSKONTO adı geçen TÜM tablolar (tedarikçi primi ayrı mı)"
$PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public'
          AND table_name ~* 'iskonto|prim|tesvik|ristorno|hakedis|rebate|bonus|indirim|fiyat_list|price' ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "2. FİYAT LİSTESİ çekmecesi"
say bi_fiyat_listesi_kalemler
say bi_fiyat_listesi_uploads

hr "3. İSKONTO/PRİM çekmecesi (satış tarafı mı, tedarikçi mi)"
say bi_fiyat_iskonto

hr "4. bi_fiyat_iskonto örnek 2 satır (ne tutuyor — kime, ne primi)"
$PSQL -x -c "SELECT * FROM bi_fiyat_iskonto WHERE tenant_id='$T'::uuid LIMIT 2;" 2>&1 | head -40 | sed 's/^/  /'

hr "5. bi_fiyat_listesi_kalemler örnek 2 satır (liste fiyatı mı, alış mı satış mı)"
$PSQL -x -c "SELECT * FROM bi_fiyat_listesi_kalemler LIMIT 2;" 2>&1 | head -40 | sed 's/^/  /'

hr "BITTI — fiyat listesi + satış primi elimizde mi, TEDARİKÇİ primi var mı yoksa SAP boşluğu mu net."
