#!/usr/bin/env bash
# OMURGA 37c — metrik_marj_atom_uret: TEK range-join (satır-başına alt-sorgu YOK). Hızlı.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ÜRETİCİ v3 — tek küme-tabanlı range-join"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION metrik_marj_atom_uret(p_tenant uuid, p_ay_geri int DEFAULT 24) RETURNS int AS $fn$
DECLARE n int; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  DELETE FROM bi_marj_atom WHERE tenant_id=p_tenant AND ay >= m0 - make_interval(months=>p_ay_geri);

  CREATE TEMP TABLE _pur ON COMMIT DROP AS
    SELECT kalem_kodu, date_trunc('month',belge_tarihi)::date ay, sum(giris_tutari) gt, sum(giris) g
      FROM bi_stok_hareket WHERE tenant_id=p_tenant AND giris>=5 AND giris_tutari>0 GROUP BY 1,2;
  CREATE INDEX ON _pur(kalem_kodu, ay);

  CREATE TEMP TABLE _allb ON COMMIT DROP AS
    SELECT kalem_kodu, sum(gt)/NULLIF(sum(g),0) c FROM _pur GROUP BY kalem_kodu;
  CREATE INDEX ON _allb(kalem_kodu);

  CREATE TEMP TABLE _sal ON COMMIT DROP AS
    SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, max(marka) marka, max(ebat) ebat, max(kategori) kategori,
           sum(miktar) adet, sum(satir_tutar) ciro
      FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND ebat IS NOT NULL AND miktar>0
        AND fatura_tarihi >= m0 - make_interval(months=>p_ay_geri) AND fatura_tarihi < m0 GROUP BY 1,2;
  CREATE INDEX ON _sal(kalem_kodu, ay);

  INSERT INTO bi_marj_atom (tenant_id,kalem_kodu,ay,marka,ebat,kategori,adet,ciro,ort_fiyat,birim_maliyet,maliyet_kaynak,brut_kar,marj_pct)
  SELECT p_tenant, x.kalem_kodu, x.ay, x.marka, x.ebat, x.kategori, x.adet, x.ciro,
         round(x.ciro/NULLIF(x.adet,0)), round(x.cost), x.kaynak,
         round(x.ciro - x.adet*x.cost), round(100*(x.ciro - x.adet*x.cost)/NULLIF(x.ciro,0),1)
  FROM (
    SELECT sl.kalem_kodu, sl.ay, sl.marka, sl.ebat, sl.kategori, sl.adet, sl.ciro,
           COALESCE(sum(p.gt)/NULLIF(sum(p.g),0), max(ab.c)) cost,
           CASE WHEN sum(p.g) IS NOT NULL THEN 'donem' ELSE 'fallback' END kaynak
      FROM _sal sl
      LEFT JOIN _pur p ON p.kalem_kodu=sl.kalem_kodu AND p.ay >= sl.ay - interval '6 month' AND p.ay <= sl.ay
      LEFT JOIN _allb ab ON ab.kalem_kodu=sl.kalem_kodu
      GROUP BY sl.kalem_kodu, sl.ay, sl.marka, sl.ebat, sl.kategori, sl.adet, sl.ciro
  ) x
  WHERE x.cost IS NOT NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ v3 range-join"

hr "2. ÜRET — KRB (süreyi ölç)"
time $PSQL -c "SELECT metrik_marj_atom_uret('$T'::uuid, 24) AS atom_satir;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT round(100.0*count(*) FILTER (WHERE maliyet_kaynak='donem')/count(*)) donem_kapsam_pct, count(*) FROM bi_marj_atom WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "3. DOĞRULAMA — marka marjı atomdan (son 6 ay)"
$PSQL -c "SELECT marka, round(sum(ciro)/1e6,1) ciro_m, round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj_pct FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY marka HAVING sum(ciro)>10000000 ORDER BY ciro_m DESC LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "BITTI"
