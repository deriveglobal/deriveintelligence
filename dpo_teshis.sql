-- DPO 239 teşhis (READ-ONLY) — bilanço-DPO şişkin mi? Taban uyuşmazlığı (tüm-tedarikçi borç ÷ yalnız-lastik SMM)?
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '===== 1) v_finans_ticari_sermaye — DPO ve bileşenleri ====='
SELECT dso, dio, dpo, ccc,
       round(ar_net/1e6,1) alacak_net_m, round(ap_borc/1e6,1) borc_m, round(net_satis/1e6,1) net_satis_m,
       round(smm/1e6,1) smm_m
  FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'t';

\echo '===== 2) TİCARİ BORÇ kaynağı — bi_cari_bakiye tedarikçi borcu (TÜM tedarikçi) ====='
SELECT round(sum(-LEAST(tedarikci_bakiye,0))/1e6,1) toplam_borc_m, count(*) FILTER (WHERE tedarikci_bakiye<0) borclu_tedarikci
  FROM bi_cari_bakiye WHERE tenant_id::text=:'t';

\echo '===== 3) ALIM tabanı — 12 ay TÜM alım vs YALNIZ lastik (taban uyuşmazlığı büyüklüğü) ====='
SELECT round(sum(satir_kdv_haric) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365)/1e6,1) tum_alim_12ay_m,
       round(sum(satir_kdv_haric) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365 AND grup_adi ILIKE '%LASTIK%')/1e6,1) lastik_alim_12ay_m
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0;

\echo '===== 4) SÖZLEŞME DPO — ağırlıklı vade_gun (fiilen ne kadar vade alıyorsun) ====='
SELECT round(sum(vade_gun*satir_kdv_haric)/NULLIF(sum(satir_kdv_haric),0),1) sozlesme_vade_gun
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 AND vade_gun IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-365;

\echo '===== 5) DPO VARYANTLARI — aynı borç, farklı taban ====='
WITH v AS (SELECT ap_borc, smm FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'t'),
alim AS (SELECT sum(satir_kdv_haric) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365) tum,
                sum(satir_kdv_haric) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365 AND grup_adi ILIKE '%LASTIK%') lastik
           FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0)
SELECT round(v.ap_borc/NULLIF(v.smm,0)*365) dpo_borc_bolu_lastikSMM_MEVCUT,
       round(v.ap_borc/NULLIF(alim.tum,0)*365) dpo_borc_bolu_TUM_ALIM,
       round(v.ap_borc/NULLIF(alim.lastik,0)*365) dpo_borc_bolu_LASTIK_ALIM
  FROM v, alim;
