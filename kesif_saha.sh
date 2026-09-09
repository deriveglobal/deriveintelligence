#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
S=/opt/krb-assessment/server_container.mjs
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. SAHA TABLOLARI + SATIR + TAZELIK"
for t in $($PSQL -Atc "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ~* 'saha|ziyaret|teklif|temsilci|niyet|duyuru' AND table_name NOT LIKE 'yedek_%' ORDER BY 1"); do
  ts=$($PSQL -Atc "SELECT column_name FROM information_schema.columns WHERE table_name='$t' AND column_name IN ('created_at','ts','olusturuldu_at','tarih','ziyaret_tarihi','teklif_tarihi','guncellendi_at') ORDER BY 1 LIMIT 1")
  if [ -n "$ts" ]; then echo "-- $t"; $PSQL -Atc "SELECT count(*)||' satir | son: '||coalesce(max($ts)::text,'-') FROM $t"; else echo "-- $t"; $PSQL -Atc "SELECT count(*)||' satir (ts yok)' FROM $t"; fi
done

hr "2. SAHA TABLO KOLONLARI"
$PSQL -c "SELECT table_name||' :: '||string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='public' AND table_name ~* 'saha|ziyaret|temsilci|niyet' AND table_name NOT LIKE 'yedek_%' GROUP BY table_name ORDER BY 1;"

hr "3. /api/saha ENDPOINT'LERI"
grep -noE "/api/saha/[a-z0-9_-]+" "$S" | sort -u | head -50

hr "4. KULLANICI/REP TABLOSU"
$PSQL -Atc "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ~* 'kullanic|^user|hesap|personel|uye' ORDER BY 1;"

hr "5. SON 7 GUN — bi_etkinlik/log'da saha izi (varsa)"
$PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ~* 'etkinlik|log|olay|activity|denetim' ORDER BY 1;" 2>&1 | head -15
