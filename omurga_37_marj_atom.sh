#!/usr/bin/env bash
# OMURGA 37 — KANONİK MARJ ATOMU: SKU×ay (fiyat, dönem-maliyet, adet). Her marj türevi buradan. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ŞEMA — bi_marj_atom (SKU×ay kanonik)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_marj_atom (
  tenant_id uuid, kalem_kodu text, ay date, marka text, ebat text, kategori text,
  adet numeric, ciro numeric, ort_fiyat numeric,
  birim_maliyet numeric, maliyet_kaynak text, brut_kar numeric, marj_pct numeric,
  hesaplanma_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, kalem_kodu, ay));
CREATE INDEX IF NOT EXISTS ix_marjatom ON bi_marj_atom(tenant_id, marka, ay);
SQL
echo "  ✅ bi_marj_atom"

hr "2. ÜRETİCİ — metrik_marj_atom_uret (dönem-eşleşmeli maliyet, son N ay)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION metrik_marj_atom_uret(p_tenant uuid, p_ay_geri int DEFAULT 24) RETURNS int AS $fn$
DECLARE n int; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  DELETE FROM bi_marj_atom WHERE tenant_id=p_tenant AND ay >= m0 - make_interval(months=>p_ay_geri);
  INSERT INTO bi_marj_atom (tenant_id,kalem_kodu,ay,marka,ebat,kategori,adet,ciro,ort_fiyat,birim_maliyet,maliyet_kaynak,brut_kar,marj_pct)
  SELECT p_tenant, sa.kalem_kodu, sa.ay, sa.marka, sa.ebat, sa.kategori, sa.adet, sa.ciro,
         round(sa.ciro/NULLIF(sa.adet,0)) ort_fiyat,
         round(c.cost) birim_maliyet, c.kaynak,
         round(sa.ciro - sa.adet*c.cost) brut_kar,
         round(100*(sa.ciro - sa.adet*c.cost)/NULLIF(sa.ciro,0),1) marj_pct
  FROM (
    SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, max(marka) marka, max(ebat) ebat, max(kategori) kategori,
           sum(miktar) adet, sum(satir_tutar) ciro
      FROM bi_satis_faturalari
     WHERE tenant_id::text=p_tenant::text AND ebat IS NOT NULL AND miktar>0
       AND fatura_tarihi >= m0 - make_interval(months=>p_ay_geri) AND fatura_tarihi < m0
     GROUP BY 1,2) sa
  CROSS JOIN LATERAL (
    SELECT COALESCE(d.c, f.c) cost, CASE WHEN d.c IS NOT NULL THEN 'donem' ELSE 'fallback' END kaynak
    FROM (SELECT sum(h.giris_tutari)/NULLIF(sum(h.giris),0) c FROM bi_stok_hareket h
            WHERE h.tenant_id=p_tenant AND h.kalem_kodu=sa.kalem_kodu AND h.giris>=5 AND h.giris_tutari>0
              AND h.belge_tarihi >= sa.ay - interval '6 month' AND h.belge_tarihi < sa.ay + interval '1 month') d
    CROSS JOIN (SELECT sum(h.giris_tutari)/NULLIF(sum(h.giris),0) c FROM bi_stok_hareket h
            WHERE h.tenant_id=p_tenant AND h.kalem_kodu=sa.kalem_kodu AND h.giris>=5 AND h.giris_tutari>0) f
  ) c
  WHERE c.cost IS NOT NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ metrik_marj_atom_uret"

hr "3. ÜRET — KRB (son 24 ay)"
$PSQL -c "SELECT metrik_marj_atom_uret('$T'::uuid, 24) AS atom_satir;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT round(100.0*count(*) FILTER (WHERE maliyet_kaynak='donem')/count(*)) donem_kapsam_pct, count(*) FROM bi_marj_atom WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "4. TÜREV DOĞRULAMA — marka marjı ATOMDAN (son 6 ay) vs önceki diagnostik (LASSA~5, CONTINENTAL~5.5)"
$PSQL -c "
SELECT marka, round(sum(ciro)/1e6,1) ciro_m, round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj_pct_atomdan
  FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month'
 GROUP BY marka HAVING sum(ciro)>10000000 ORDER BY ciro_m DESC LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "5. TÜREV DOĞRULAMA — CONTINENTAL aylık marj trendi ATOMDAN (23%→~8% çıkmalı)"
$PSQL -c "
SELECT to_char(ay,'YYYY-MM') ay, round(sum(ciro)/1e6,1) ciro_m, round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj_pct
  FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)='CONTINENTAL' AND ay>=date_trunc('month',CURRENT_DATE)-interval '12 month'
 GROUP BY ay ORDER BY ay;" 2>&1 | sed 's/^/  /'

hr "BITTI — atom canlı; marka/mix/trend hepsi tek kaynaktan türüyor. Sonra drill/içgörü/köprü buna bağlanır."
