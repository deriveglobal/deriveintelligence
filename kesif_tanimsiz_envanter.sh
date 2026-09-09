#!/usr/bin/env bash
# TANIMSIZ ENVANTER — defterdeki tanımsız parçalar + kanıt (kolonlar/isim). Toplu taslak için. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TANIMSIZ TABLOLAR + kolonları (kanıttan)"
$PSQL -tA -F'|' -c "
SELECT ad, array_to_string((SELECT array_agg(x) FROM jsonb_array_elements_text(kanit->'kolonlar') x),',')
  FROM bi_yetenek WHERE tur='tablo' AND durum='tanimsiz' ORDER BY ad;" 2>&1 | sed 's/^/  /'

hr "2. TANIMSIZ FONKSİYONLAR"
$PSQL -tA -c "SELECT ad FROM bi_yetenek WHERE tur='fonksiyon' AND durum='tanimsiz' ORDER BY ad;" 2>&1 | tr '\n' ' ' | fold -s -w 150 | sed 's/^/  /'

hr "3. TANIMSIZ ENDPOINT'LER"
$PSQL -tA -c "SELECT ad FROM bi_yetenek WHERE tur='endpoint' AND durum='tanimsiz' ORDER BY ad;" 2>&1 | tr '\n' ' ' | fold -s -w 150 | sed 's/^/  /'

hr "4. TANIMSIZ CRON'LAR"
$PSQL -tA -c "SELECT ad FROM bi_yetenek WHERE tur='cron' AND durum='tanimsiz' ORDER BY ad;" 2>&1 | sed 's/^/  /'

hr "5. DURUM — kaç tanımlı vs tanımsız (hedef %100)"
$PSQL -c "SELECT tur, count(*) FILTER (WHERE durum IN ('taslak','onayli')) tanimli, count(*) FILTER (WHERE durum='tanimsiz') tanimsiz, round(100.0*count(*) FILTER (WHERE durum IN ('taslak','onayli'))/count(*)) yuzde FROM bi_yetenek GROUP BY tur ORDER BY tur;" 2>&1 | sed 's/^/  /'

hr "BITTI — envanter + mevcut kapsam %. Bunu görünce toplu taslak yazarım."
