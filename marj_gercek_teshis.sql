-- MARJ_GERCEK_V1 vs KANON teşhis (READ-ONLY). /api/bi/ana "Bugün" marj'ı kanondan ne kadar/ne yüzden sapıyor?
-- MARJ_GERCEK: SMM=bi_stok_hareket.cikis_tutari (ERP sevk maliyeti), ciro=bi_satis TIC+TUK, marj=1-SMM/ciro.
-- KANON: bi_marj_atom (akış maliyeti), marj=Σbrut_kar/Σciro.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo '===== 1) MARJ_GERCEK_V1 (endpoint birebir, 365g) ====='
WITH mus AS (SELECT DISTINCT musteri_kodu FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND fatura_tarihi >= CURRENT_DATE-365),
     smm AS (SELECT sum(h.cikis_tutari) maliyet, sum(h.cikis) adet FROM bi_stok_hareket h JOIN mus m ON m.musteri_kodu=h.muhatap_kodu
              WHERE h.tenant_id::text=:'t' AND h.belge_tarihi >= CURRENT_DATE-365 AND h.hareket_sinifi IN ('SATIS_SEVK','SATIS_FATURA') AND h.grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI') AND h.cikis>0),
     ciro AS (SELECT sum(satir_tutar) c, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND fatura_tarihi >= CURRENT_DATE-365 AND grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI'))
SELECT 'MARJ_GERCEK (ERP cikis_tutari, TIC+TUK)' kaynak, round(smm.maliyet/1e6,1) smm_m, round(ciro.c/1e6,1) ciro_m,
       round(100.0*(1-smm.maliyet/nullif(ciro.c,0)),1) marj_pct, round(100.0*smm.adet/nullif(ciro.adet,0)) mutabakat_adet_pct
  FROM smm, ciro;

\echo '===== 2) KANON atom — akış maliyeti, 12 ay (marj_pct = Σbrut_kar/Σciro) ====='
SELECT 'KANON atom (akis maliyet)' kaynak, round(sum(ciro-brut_kar)/1e6,1) smm_m, round(sum(ciro)/1e6,1) ciro_m,
       round(100.0*sum(brut_kar)/nullif(sum(ciro),0),1) marj_pct,
       round(100.0*count(*) FILTER (WHERE maliyet_kaynak='donem')/nullif(count(*),0)) marj_kapsam_pct
  FROM bi_marj_atom
 WHERE tenant_id::text=:'t' AND ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '12 months';

\echo '===== 3) Ciro tabani farki: bi_satis LASTIK% (kanon ciro) vs TIC+TUK (MARJ_GERCEK) vs atom.ciro (matched) ====='
SELECT 'bi_satis LASTIK% (kanon ciro)' k, round(sum(satir_tutar)/1e6,1) ciro_m FROM bi_satis_faturalari
 WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi>=CURRENT_DATE-365 AND grup_adi LIKE 'LASTIK%'
UNION ALL
SELECT 'bi_satis TIC+TUK (retread haric)', round(sum(satir_tutar)/1e6,1) FROM bi_satis_faturalari
 WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi>=CURRENT_DATE-365 AND grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI')
UNION ALL
SELECT 'atom.ciro (maliyet-eslesen)', round(sum(ciro)/1e6,1) FROM bi_marj_atom
 WHERE tenant_id::text=:'t' AND ay>=date_trunc('month',CURRENT_DATE)-INTERVAL '12 months';
