#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -v ON_ERROR_STOP=1 -U assessment_app -d assessment_platform"

$PSQL <<'SQL'
\pset pager off
\set KRB 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\set ANA '42822870-4ea3-424d-a16f-50b91afca32c'
\echo '========== AGNOSTIK CANARY — tenant izolasyon + metrik tenant-ayrikligi =========='

DROP TABLE IF EXISTS _canary;
CREATE TEMP TABLE _canary(sira int, probe text, tur text, krb numeric, ana numeric);
INSERT INTO _canary VALUES
 (1,'bi_marj_atom count','strict',
   (SELECT count(*) FROM bi_marj_atom          WHERE tenant_id::text=:'KRB'),
   (SELECT count(*) FROM bi_marj_atom          WHERE tenant_id::text=:'ANA')),
 (2,'bi_marj_fact count','strict',
   (SELECT count(*) FROM bi_marj_fact          WHERE tenant_id::text=:'KRB'),
   (SELECT count(*) FROM bi_marj_fact          WHERE tenant_id::text=:'ANA')),
 (3,'bi_satis ciro','strict',
   (SELECT round(sum(satir_tutar)) FROM bi_satis_faturalari WHERE tenant_id::text=:'KRB' AND satir_tutar>0),
   (SELECT round(sum(satir_tutar)) FROM bi_satis_faturalari WHERE tenant_id::text=:'ANA' AND satir_tutar>0)),
 (4,'v_finans dso','view',
   (SELECT round(dso) FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'),
   (SELECT round(dso) FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'ANA'));

SELECT sira, probe, tur, krb, ana,
  CASE
    WHEN tur='strict' AND (krb IS NULL OR ana IS NULL) THEN 'FAIL-null/hata'
    WHEN tur='strict' AND (krb=0 OR ana=0)             THEN 'FAIL-sifir'
    WHEN tur='strict' AND krb=ana                      THEN 'FAIL-ESIT (tenant-filtre kacti!)'
    WHEN tur='view'   AND krb IS NULL                  THEN 'FAIL-KRB-null (metrik bozuk)'
    WHEN tur='view'   AND ana IS NULL                  THEN 'OK (ana feed yok, atlandi)'
    WHEN tur='view'   AND krb=ana                      THEN 'FAIL-ESIT (tenant-filtre kacti!)'
    ELSE 'OK'
  END AS verdict
FROM _canary ORDER BY sira;

DO $$
DECLARE r record; n int:=0;
BEGIN
  FOR r IN SELECT * FROM _canary ORDER BY sira LOOP
    IF r.tur='strict' AND (r.krb IS NULL OR r.ana IS NULL OR r.krb=0 OR r.ana=0 OR r.krb=r.ana) THEN
      RAISE WARNING 'CANARY FAIL [%]: % (krb=% ana=%)', r.sira, r.probe, r.krb, r.ana; n:=n+1;
    ELSIF r.tur='view' AND (r.krb IS NULL OR (r.ana IS NOT NULL AND r.krb=r.ana)) THEN
      RAISE WARNING 'CANARY FAIL [%]: % (krb=% ana=%)', r.sira, r.probe, r.krb, r.ana; n:=n+1;
    END IF;
  END LOOP;
  IF n>0 THEN
    RAISE EXCEPTION 'CANARY: % probe FAIL -> tenant izolasyonu/metrik SUPHEDE', n;
  END IF;
  RAISE NOTICE 'CANARY OK: tum probe tenant-ayrik, KRB metrikleri saglam.';
END $$;
SQL
rc=$?

echo "------------------------------------------------------------"
if [ "$rc" -eq 0 ]; then
  echo "==> CANARY: PASS (rc=0) — tenant izolasyonu saglam, metrikler tenant-ayrik."
else
  echo "==> CANARY: FAIL (rc=$rc) — bir metrik tenant-ayrik degil ya da patliyor."
  echo "    Muhtemel sebep: yeni bir sorgu tenant_id filtresini kacirdi (veri sizabilir)."
  echo "    Son deploy'u incele / rollback dusun."
fi
exit $rc
