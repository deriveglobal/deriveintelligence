#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ADAY TABLOLAR (app DB)"
$PSQL -Atc "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ~* 'rakip|piyasa|scrap|monitor|esles|alarm|competitor|price|endeks|index' ORDER BY 1;"

hr "2. KOLONLAR"
$PSQL -Atc "SELECT table_name||'  ::  '||string_agg(column_name||':'||data_type,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='public' AND table_name ~* 'rakip|piyasa|scrap|monitor|esles|alarm|competitor' GROUP BY table_name ORDER BY 1;"

hr "3. SATIR SAYISI + EN TAZE TS"
for t in $($PSQL -Atc "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ~* 'rakip|piyasa|scrap|esles|alarm|competitor'"); do
  echo "-- $t"; $PSQL -Atc "SELECT count(*), max(coalesce(guncelleme, olusma, ts, created_at, tarih)::text) FROM $t" 2>/dev/null || echo "   (ts kolonu farkli)";
done

hr "4. server_container.mjs — mevcut endpoint + mantik"
grep -nE "/api/rakip|/api/piyasa|url\.pathname.*(rakip|piyasa)" /opt/krb-assessment/server_container.mjs | head -20
grep -nE "rakip|piyasa|eslesme|alarm_esik|en_dusuk|competitor" /opt/krb-assessment/server_container.mjs | grep -iE "SELECT|FROM|query\(|JOIN" | head -20

hr "5. /opt/price_monitor — yapi + hedef DB/tablo"
ls -la /opt/price_monitor 2>&1 | head -20
grep -rhoiE "dbname=[a-zA-Z_]+|assessment_platform|INSERT INTO [a-zA-Z_.]+|CREATE TABLE [a-zA-Z_.]+|UPDATE [a-zA-Z_.]+ SET" /opt/price_monitor 2>/dev/null | sort -u | head -30
