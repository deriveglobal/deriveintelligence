-- DPO tutarlı taban FIX — hazırlık (READ-ONLY). Lastik-tedarikçi borcu → dürüst DPO + CCC + view tanımı.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '===== 1) LASTİK-TEDARİKÇİ borcu (lastik alımı olan tedarikçiler) vs tüm borç ====='
WITH ts AS (SELECT DISTINCT tedarikci_kodu FROM bi_tedarikci_faturalari
              WHERE tenant_id::text=:'t' AND grup_adi ILIKE '%LASTIK%' AND tedarikci_kodu IS NOT NULL)
SELECT (SELECT count(*) FROM ts) lastik_tedarikci_say,
       round(sum(-LEAST(cb.tedarikci_bakiye,0)) FILTER (WHERE cb.tedarikci_kodu IN (SELECT tedarikci_kodu FROM ts))/1e6,1) lastik_borc_m,
       round(sum(-LEAST(cb.tedarikci_bakiye,0))/1e6,1) tum_borc_m,
       round(100*sum(-LEAST(cb.tedarikci_bakiye,0)) FILTER (WHERE cb.tedarikci_kodu IN (SELECT tedarikci_kodu FROM ts))
             /NULLIF(sum(-LEAST(cb.tedarikci_bakiye,0)),0))::int lastik_pay_pct
  FROM bi_cari_bakiye cb WHERE cb.tenant_id::text=:'t';

\echo '===== 2) TUTARLI DPO + CCC (view SMM aynen; dpo_yeni = dpo × lastik_borc/tum_borc) ====='
WITH ts AS (SELECT DISTINCT tedarikci_kodu FROM bi_tedarikci_faturalari
              WHERE tenant_id::text=:'t' AND grup_adi ILIKE '%LASTIK%' AND tedarikci_kodu IS NOT NULL),
b AS (SELECT sum(-LEAST(tedarikci_bakiye,0)) tum,
             sum(-LEAST(tedarikci_bakiye,0)) FILTER (WHERE tedarikci_kodu IN (SELECT tedarikci_kodu FROM ts)) lastik
        FROM bi_cari_bakiye WHERE tenant_id::text=:'t')
SELECT v.dso, v.dio, v.dpo dpo_eski, v.ccc ccc_eski,
       round(v.dpo * b.lastik / NULLIF(b.tum,0)) dpo_yeni,
       round(v.dso + v.dio - v.dpo * b.lastik / NULLIF(b.tum,0)) ccc_yeni
  FROM v_finans_ticari_sermaye v, b WHERE v.tenant_id::text=:'t';

\echo '===== 3) VIEW TANIMI — ap_borc / dpo / ccc nerede hesaplanıyor ====='
SELECT pg_get_viewdef('v_finans_ticari_sermaye'::regclass, true);
