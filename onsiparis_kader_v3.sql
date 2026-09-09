-- ÖN-SİPARİŞ KADERİ v3 (READ-ONLY) — BÜYÜME-AYARLI + ₺ MARUZİYET. Bu SQL = motorun mantığı.
-- beklenen = greatest(gecen_kis, onceki_kis) × g ; g = KRB toplam kış büyümesi (w1/w0). Aşırı = commit > beklenen.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '################ 0) KIŞ BÜYÜME FAKTÖRÜ g (toplam KRB kış adedi, YoY) ################'
SELECT w1 gecen_kis_toplam, w0 onceki_kis_toplam,
       round(GREATEST(w1::numeric/NULLIF(w0,0),0.2),3) AS g
  FROM (SELECT sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2025-10-01' AND fatura_tarihi<DATE '2026-03-01') w1,
               sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2025-03-01') w0
          FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
           AND fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2026-03-01') x \gset

\echo :g
\echo '(yukarisi g — beklentiye uygulanan buyume carpani)'

\echo '################ 1) BÜYÜME-AYARLI KADER — ₺ maruziyete göre sıralı (top 25) ################'
WITH nrm AS (SELECT '[0-9]{3}/[0-9]{2}R[0-9]{2}C?' rx)
, pre AS (
  SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from (SELECT rx FROM nrm)) e, sum(adet) commit
    FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS' AND upper(alici)='KRB' GROUP BY 1,2)
, w AS (
  SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from (SELECT rx FROM nrm)) e,
         COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2025-10-01' AND fatura_tarihi<DATE '2026-03-01'),0) w1,
         COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2025-03-01'),0) w0
    FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
     AND fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2026-03-01' GROUP BY 1,2)
, cost AS (SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from (SELECT rx FROM nrm)) e,
                  avg(birim_maliyet_kanon) c FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365 AND birim_maliyet_kanon>0 GROUP BY 1,2)
, bcost AS (SELECT marka, avg(birim_maliyet_kanon) c FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365 AND birim_maliyet_kanon>0 GROUP BY 1)
SELECT p.marka, p.e ebat, round(p.commit) commit,
       round(GREATEST(w.w1,w.w0)) demonstre, round(GREATEST(w.w1,w.w0)*:g) beklenen_buyumeli,
       CASE WHEN GREATEST(w.w1,w.w0)*:g < 1 THEN NULL ELSE round((p.commit/(GREATEST(w.w1,w.w0)*:g))::numeric,2) END ratio,
       round(GREATEST(p.commit - GREATEST(w.w1,w.w0)*:g, 0)) fazla_adet,
       round(GREATEST(p.commit - GREATEST(w.w1,w.w0)*:g, 0) * COALESCE(cost.c,bcost.c,0)/1e6,2) maruziyet_m
  FROM pre p LEFT JOIN w ON w.marka=p.marka AND w.e=p.e
             LEFT JOIN cost ON cost.marka=p.marka AND cost.e=p.e
             LEFT JOIN bcost ON bcost.marka=p.marka
 WHERE p.e IS NOT NULL
 ORDER BY GREATEST(p.commit - GREATEST(w.w1,w.w0)*:g, 0) * COALESCE(cost.c,bcost.c,0) DESC NULLS LAST LIMIT 25;

\echo '################ 2) ÖZET — büyüme-ayarlı gerçek aşırı-bağlama (adet + ₺) ################'
WITH nrm AS (SELECT '[0-9]{3}/[0-9]{2}R[0-9]{2}C?' rx)
, pre AS (SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from (SELECT rx FROM nrm)) e, sum(adet) commit
            FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND sezon='KIS' AND upper(alici)='KRB' GROUP BY 1,2)
, w AS (SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from (SELECT rx FROM nrm)) e,
               GREATEST(COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2025-10-01' AND fatura_tarihi<DATE '2026-03-01'),0),
                        COALESCE(sum(miktar) FILTER (WHERE fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2025-03-01'),0)) demo
          FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND grup_adi LIKE 'LASTIK%'
           AND fatura_tarihi>=DATE '2024-10-01' AND fatura_tarihi<DATE '2026-03-01' GROUP BY 1,2)
, cost AS (SELECT marka, substring(upper(regexp_replace(ebat,'\s','','g')) from (SELECT rx FROM nrm)) e, avg(birim_maliyet_kanon) c
             FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365 AND birim_maliyet_kanon>0 GROUP BY 1,2)
, bcost AS (SELECT marka, avg(birim_maliyet_kanon) c FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365 AND birim_maliyet_kanon>0 GROUP BY 1)
SELECT round(sum(p.commit)) krb_commit_adet,
       round(sum(GREATEST(p.commit - COALESCE(w.demo,0)*:g,0))) fazla_adet,
       round(100*sum(GREATEST(p.commit - COALESCE(w.demo,0)*:g,0))/NULLIF(sum(p.commit),0))::int fazla_pct,
       round(sum(GREATEST(p.commit - COALESCE(w.demo,0)*:g,0)*COALESCE(cost.c,bcost.c,0))/1e6,1) maruziyet_toplam_m
  FROM pre p LEFT JOIN w ON w.marka=p.marka AND w.e=p.e
             LEFT JOIN cost ON cost.marka=p.marka AND cost.e=p.e
             LEFT JOIN bcost ON bcost.marka=p.marka WHERE p.e IS NOT NULL;
