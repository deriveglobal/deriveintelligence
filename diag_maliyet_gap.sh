#!/usr/bin/env bash
# TEKLIF_ONERI — MALIYET KAPSAM ACIGI teshisi (auth gerekmez, dogrudan DB).
#   Iddia: motor floorCost'u dar (bi_marj_atom 12ay VEYA tedarikci 90 gun). Eski alinan
#   (yavas donen, TBR) urunlerde ikisi de bos -> "maliyet yok" der, oysa SON ALIS fiyati var.
#   Bu script: (1) iki ornek SKU'nun maliyet kaynaklari, (2) sistemik: kac SKU "motor maliyet
#   yok" ama gercekte tedarikci alisi VAR (=FIXABLE), tuketici/ticari kirilimli.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_maliyet_gap.sh'
set -euo pipefail
PSQL='docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -v ON_ERROR_STOP=1'

echo "=== (1) ORNEK 2 SKU — maliyet hangi kaynakta var? ==="
$PSQL <<'SQL'
WITH t AS (SELECT id::text tid FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1),
sku AS (
  SELECT DISTINCT s.kalem_kodu, s.marka, s.ebat
  FROM bi_satis_faturalari s, t
  WHERE s.tenant_id::text=t.tid AND (
    (upper(s.marka)='BRIDGESTONE' AND s.ebat='315/80R22.5') OR
    (upper(s.marka)='LASSA' AND s.ebat='385/65R22.5')))
SELECT sk.marka, sk.ebat, sk.kalem_kodu,
  (SELECT round((SUM(a.ciro)-SUM(a.brut_kar))/NULLIF(SUM(a.adet),0)) FROM bi_marj_atom a,t
     WHERE a.tenant_id::text=t.tid AND a.kalem_kodu=sk.kalem_kodu AND a.ay>=CURRENT_DATE-INTERVAL '12 months') marj_atom_12ay,
  (SELECT round(SUM(tf.satir_kdv_haric)/NULLIF(SUM(tf.miktar),0)) FROM bi_tedarikci_faturalari tf,t
     WHERE tf.tenant_id::text=t.tid AND tf.kalem_kodu=sk.kalem_kodu AND tf.fatura_tarihi>=CURRENT_DATE-INTERVAL '90 days') repl_90gun,
  (SELECT round(SUM(tf.satir_kdv_haric)/NULLIF(SUM(tf.miktar),0)) FROM bi_tedarikci_faturalari tf,t
     WHERE tf.tenant_id::text=t.tid AND tf.kalem_kodu=sk.kalem_kodu) alis_TUM,
  (SELECT to_char(max(tf.fatura_tarihi),'YYYY-MM-DD') FROM bi_tedarikci_faturalari tf,t
     WHERE tf.tenant_id::text=t.tid AND tf.kalem_kodu=sk.kalem_kodu) son_alis_tarih,
  (SELECT count(*) FROM bi_tedarikci_faturalari tf,t
     WHERE tf.tenant_id::text=t.tid AND tf.kalem_kodu=sk.kalem_kodu) alis_kayit
FROM sku sk;
SQL

echo ""
echo "=== (2) SISTEMIK — bu yil satilan SKU'lar, maliyet kapsami (tuketici vs ticari) ==="
echo "    engine_maliyet_var = marj_atom(12ay) VEYA repl(90g)   ·   FIXABLE = motor 'yok' der ama alis VAR"
$PSQL <<'SQL'
WITH t AS (SELECT id::text tid FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1),
sold AS (
  SELECT s.kalem_kodu, bool_or(s.grup_adi ILIKE '%TICARI%') ticari
  FROM bi_satis_faturalari s, t
  WHERE s.tenant_id::text=t.tid AND s.grup_adi LIKE 'LASTIK%' AND s.miktar>0
    AND s.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'
  GROUP BY s.kalem_kodu),
enr AS (
  SELECT so.ticari,
    (EXISTS(SELECT 1 FROM bi_marj_atom a,t WHERE a.tenant_id::text=t.tid AND a.kalem_kodu=so.kalem_kodu
              AND a.ay>=CURRENT_DATE-INTERVAL '12 months' AND a.ciro>0 AND (a.ciro-a.brut_kar)<>0)
     OR EXISTS(SELECT 1 FROM bi_tedarikci_faturalari tf,t WHERE tf.tenant_id::text=t.tid AND tf.kalem_kodu=so.kalem_kodu
              AND tf.fatura_tarihi>=CURRENT_DATE-INTERVAL '90 days' AND tf.miktar>0)) engine_ok,
    EXISTS(SELECT 1 FROM bi_tedarikci_faturalari tf,t WHERE tf.tenant_id::text=t.tid AND tf.kalem_kodu=so.kalem_kodu AND tf.miktar>0) alis_any
  FROM sold so)
SELECT CASE WHEN ticari THEN 'TICARI / TBR' ELSE 'TUKETICI / PSR' END is_kolu,
  count(*) satilan_sku,
  count(*) FILTER (WHERE engine_ok) engine_maliyet_var,
  count(*) FILTER (WHERE NOT engine_ok AND alis_any) FIXABLE_alis_var,
  count(*) FILTER (WHERE NOT engine_ok AND NOT alis_any) gercekten_yok,
  round((100.0*count(*) FILTER (WHERE NOT engine_ok AND alis_any)/count(*))::numeric,1) fixable_pct
FROM enr GROUP BY ticari ORDER BY ticari;
SQL
