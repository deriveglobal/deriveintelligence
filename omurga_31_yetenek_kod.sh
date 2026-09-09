#!/usr/bin/env bash
# OMURGA 31 — "her şey iz bıraksın": yetenek defteri KOD katmanı.
# yetenek_tara() → tablo + FONKSIYON. Bash → endpoint + cron. + bi_deploy_log. DB+kod, deploy yok.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. yetenek_tara() v3 — tablo + DB fonksiyonları (pg_proc), parmak-izli yaşam döngüsü"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
DROP FUNCTION IF EXISTS yetenek_tara();
CREATE FUNCTION yetenek_tara() RETURNS jsonb AS $fn$
DECLARE yeni int:=0; degisen int:=0; kayip int:=0;
BEGIN
  CREATE TEMP TABLE _cur ON COMMIT DROP AS
    SELECT t.table_name AS ad, 'tablo' AS tur,
       md5(string_agg(c.column_name||':'||c.data_type,',' ORDER BY c.ordinal_position)) fp,
       jsonb_build_object('kolonlar', array_agg(c.column_name ORDER BY c.ordinal_position)) kanit
    FROM information_schema.tables t JOIN information_schema.columns c ON c.table_name=t.table_name AND c.table_schema='public'
    WHERE t.table_schema='public' AND t.table_type='BASE TABLE' AND t.table_name ~ '^(bi_|saha_|ops_|master_|brain_)'
    GROUP BY t.table_name
    UNION ALL
    SELECT p.proname, 'fonksiyon',
       md5(pg_get_function_identity_arguments(p.oid)||'->'||pg_get_function_result(p.oid)),
       jsonb_build_object('arg',pg_get_function_identity_arguments(p.oid),'ret',pg_get_function_result(p.oid))
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname ~ '^(metrik_|veri_saglik|icgoru_|yetenek_|bi_sku)';

  INSERT INTO bi_yetenek (ad,tur,durum,parmak_izi,son_gorulme,kanit)
  SELECT ad,tur,'tanimsiz',fp,now(),kanit FROM _cur c
  WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek y WHERE y.ad=c.ad AND y.tur=c.tur);
  GET DIAGNOSTICS yeni = ROW_COUNT;

  UPDATE bi_yetenek y SET parmak_izi=c.fp, son_gorulme=now(), kanit=COALESCE(y.kanit,c.kanit)
  FROM _cur c WHERE y.ad=c.ad AND y.tur=c.tur AND y.parmak_izi IS NULL;

  UPDATE bi_yetenek y SET
    durum = CASE WHEN y.durum IN ('onayli','taslak') THEN 'degisti' ELSE y.durum END,
    kanit = c.kanit || jsonb_build_object('eski_parmak_izi',y.parmak_izi),
    parmak_izi=c.fp, son_gorulme=now(), guncellendi_at=now()
  FROM _cur c WHERE y.ad=c.ad AND y.tur=c.tur AND y.parmak_izi IS NOT NULL AND y.parmak_izi IS DISTINCT FROM c.fp;
  GET DIAGNOSTICS degisen = ROW_COUNT;

  UPDATE bi_yetenek y SET son_gorulme=now() FROM _cur c WHERE y.ad=c.ad AND y.tur=c.tur;

  UPDATE bi_yetenek y SET durum='kayip', aktif=false, guncellendi_at=now()
  WHERE y.tur IN ('tablo','fonksiyon') AND y.durum<>'kayip'
    AND NOT EXISTS (SELECT 1 FROM _cur c WHERE c.ad=y.ad AND c.tur=y.tur);
  GET DIAGNOSTICS kayip = ROW_COUNT;

  RETURN jsonb_build_object('yeni',yeni,'degisen',degisen,'kayip',kayip);
END; $fn$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS bi_deploy_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bijs_hash text, aciklama text, yetenek_ozet jsonb, ts timestamptz DEFAULT now());
SQL
echo "  ✅ yetenek_tara v3 + bi_deploy_log"
$PSQL -c "SELECT yetenek_tara() AS db_tara;" 2>&1 | sed 's/^/  /'

hr "2. KOD KATMANI — endpoint (server_container.mjs) + cron → defter"
{
  echo "CREATE TEMP TABLE _kod(ad text, tur text, fp text);"
  grep -oE "url\.pathname === '/api/[^']+'" server_container.mjs | grep -oE "/api/[^']+" | sort -u | while read -r p; do
    echo "INSERT INTO _kod VALUES('$p','endpoint',md5('$p'));"
  done
  crontab -l 2>/dev/null | grep -vE '^\s*#|^\s*$' | while read -r line; do
    ad=$(printf '%s' "$line" | sed "s/'//g" | cut -c1-90)
    fp=$(printf '%s' "$line" | md5sum | cut -c1-32)
    echo "INSERT INTO _kod VALUES('$ad','cron','$fp');"
  done
  cat <<'D'
  INSERT INTO bi_yetenek(ad,tur,durum,parmak_izi,son_gorulme)
    SELECT ad,tur,'tanimsiz',fp,now() FROM _kod k WHERE NOT EXISTS(SELECT 1 FROM bi_yetenek y WHERE y.ad=k.ad AND y.tur=k.tur);
  UPDATE bi_yetenek y SET
    durum=CASE WHEN y.durum IN('onayli','taslak') AND y.parmak_izi IS DISTINCT FROM k.fp AND y.parmak_izi IS NOT NULL THEN 'degisti' ELSE y.durum END,
    parmak_izi=k.fp, son_gorulme=now() FROM _kod k WHERE y.ad=k.ad AND y.tur=k.tur;
  UPDATE bi_yetenek y SET durum='kayip',aktif=false
    WHERE y.tur IN('endpoint','cron') AND y.durum<>'kayip' AND NOT EXISTS(SELECT 1 FROM _kod k WHERE k.ad=y.ad AND k.tur=y.tur);
  SELECT tur, count(*) FROM _kod GROUP BY tur;
D
} | $PSQL 2>&1 | sed 's/^/  /'

hr "3. DEPLOY-LOG — bu tarama bir satır bıraksın (bi.js hash + yetenek özeti)"
BIJS_HASH=$(md5sum shells/bi.js | cut -c1-10)
$PSQL -c "INSERT INTO bi_deploy_log(bijs_hash,aciklama,yetenek_ozet)
  SELECT '$BIJS_HASH','omurga_31 yetenek kod-katmani tarama',
    (SELECT jsonb_object_agg(tur,c) FROM (SELECT tur,count(*) c FROM bi_yetenek GROUP BY tur) x);" 2>&1 | sed 's/^/  /'

hr "4. DEFTER — tür × durum dağılımı (tablo/fonksiyon/endpoint/cron × onayli/taslak/tanimsiz/kayip)"
$PSQL -c "SELECT tur, durum, count(*) FROM bi_yetenek GROUP BY tur,durum ORDER BY tur,durum;" 2>&1 | sed 's/^/  /'

hr "5. ÖRNEK — kayda düşen endpoint + fonksiyonlardan ilk 10'ar"
$PSQL -c "SELECT ad FROM bi_yetenek WHERE tur='endpoint' ORDER BY ad LIMIT 10;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT ad FROM bi_yetenek WHERE tur='fonksiyon' ORDER BY ad LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "6. DEPLOY-LOG son kayıt"
$PSQL -c "SELECT ts::timestamp(0), bijs_hash, yetenek_ozet FROM bi_deploy_log ORDER BY ts DESC LIMIT 1;" 2>&1 | sed 's/^/  /'

hr "BITTI — tablo+fonksiyon+endpoint+cron hepsi defterde, parmak-izli. Her deploy iz bırakır."
