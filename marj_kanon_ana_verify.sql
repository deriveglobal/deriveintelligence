-- MARJ_KANON_ANA_V1 — deploy ONCESI: yeni query #6'nin birebir formu kanon veriyor mu?
-- Beklenen: marj_pct ~11,5 · ciro ~801 (Finans/Kokpit ile ayni; eski 14,8 DEGIL).
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
WITH ciro AS (SELECT sum(satir_tutar) AS c, sum(miktar) AS adet FROM bi_satis_faturalari
               WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi >= CURRENT_DATE-365 AND grup_adi LIKE 'LASTIK%'),
     atom AS (SELECT sum(brut_kar) AS bk, sum(ciro) AS ac,
                     ROUND(100.0*count(*) FILTER (WHERE maliyet_kaynak='donem')/NULLIF(count(*),0)) AS kapsam
                FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay >= date_trunc('month',CURRENT_DATE) - INTERVAL '12 months')
SELECT round(ciro.c/1e6,1) ciro_m,
       round(ciro.c*(1 - atom.bk/NULLIF(atom.ac,0))/1e6,1) smm_m,
       round(100.0*atom.bk/NULLIF(atom.ac,0),1) marj_pct,
       atom.kapsam mutabakat_pct
  FROM ciro, atom;
