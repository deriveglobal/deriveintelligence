\pset pager off
\set KRB 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\echo '=== metrik_ciro(fn) vs direct ebat-filtre (KRB, 2026-07) — ESIT olmali ==='
SELECT 'metrik_ciro fn' k, metrik_ciro(:'KRB'::uuid, '2026-07-01'::date, true) v
UNION ALL
SELECT 'direct ebat', (SELECT COALESCE(sum(satir_tutar),0) FROM bi_satis_faturalari
   WHERE tenant_id=:'KRB'::text AND miktar>0 AND ebat IS NOT NULL
     AND fatura_tarihi>='2026-07-01'::date AND fatura_tarihi<'2026-08-01'::date);
\echo '=== esdeger (t bekleriz -> KRB ciro_lastik birebir) ==='
SELECT metrik_ciro(:'KRB'::uuid, '2026-07-01'::date, true)
     = (SELECT COALESCE(sum(satir_tutar),0) FROM bi_satis_faturalari
        WHERE tenant_id=:'KRB'::text AND miktar>0 AND ebat IS NOT NULL
          AND fatura_tarihi>='2026-07-01'::date AND fatura_tarihi<'2026-08-01'::date) AS esdeger;
