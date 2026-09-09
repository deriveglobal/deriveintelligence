#!/usr/bin/env bash
# OMURGA 42 — yetenek_tara fonksiyon-taraması KÖR NOKTA fix: önek-listesi yerine TÜM public fonksiyon.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. yetenek_tara v4 — fonksiyon taraması: public şema, eklenti-olmayan, TÜM fonksiyonlar"
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
    WHERE n.nspname='public' AND p.prokind='f'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid=p.oid AND d.deptype='e');  -- eklenti fonksiyonu hariç

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
SQL
echo "  ✅ yetenek_tara v4"

hr "2. TARA — kör nokta kapandı mı (sebep_arastir_marj düşmeli)"
$PSQL -c "SELECT yetenek_tara() AS sonuc;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT tur, count(*) FROM bi_yetenek WHERE tur='fonksiyon' GROUP BY 1;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT ad FROM bi_yetenek WHERE tur='fonksiyon' ORDER BY ad;" 2>&1 | sed 's/^/  /'

hr "BITTI — fonksiyon kör noktası kapandı; artık her yeni fonksiyon (önek fark etmez) deftere düşer."
