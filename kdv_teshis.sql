-- KDV BAZI teşhis (READ-ONLY) — her kaynak KDV-hariç mi dahil mi, KANITLA. Sonra gerekirse düzeltiriz.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '===== 1) ALIM (bi_tedarikci_faturalari) — kesin: dahil/hariç oranı = KDV oranı ====='
SELECT round(avg(kdv_orani),1) ort_kdv_orani_pct,
       round(sum(satir_kdv_dahil)/NULLIF(sum(satir_kdv_haric),0),4) agirlikli_dahil_bolu_haric,
       round(sum(satir_kdv_haric)/1e6,1) haric_m, round(sum(satir_kdv_dahil)/1e6,1) dahil_m
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 AND fatura_tarihi>=CURRENT_DATE-365;

\echo '===== 2) SATIŞ (bi_satis_faturalari) — satir_tutar net mi? (= miktar×birim_fiyat) + marj cirosuyla kıyas ====='
SELECT round(sum(satir_tutar)/1e6,1) satir_tutar_m,
       round(sum(miktar*birim_fiyat)/1e6,1) miktar_x_birimfiyat_m,
       round(sum(satir_tutar)/NULLIF(sum(miktar*birim_fiyat),0),4) oran
  FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi>=CURRENT_DATE-365 AND grup_adi LIKE 'LASTIK%';
\echo '--- 2b) satış cirosu (lastik, 12ay) vs bi_marj_atom ciro (bilinen KDV-hariç marj bazı) — eşleşiyorsa satış da hariç ---'
SELECT (SELECT round(sum(satir_tutar)/1e6,1) FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND grup_adi LIKE 'LASTIK%' AND fatura_tarihi>=CURRENT_DATE-365) satis_lastik_m,
       (SELECT round(sum(ciro)/1e6,1) FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365) marj_atom_ciro_m;

\echo '===== 3) BAKİYE (bi_cari_bakiye) — en büyük 3 tedarikçi: borç vs o tedarikçiden 12ay alım (haric & dahil) ====='
\echo '   borç, alım-dahile mi alım-harice mi yakın? (dahile yakınsa bakiye KDV-dahil)'
WITH mc AS (SELECT max(export_date) d FROM bi_cari_bakiye WHERE tenant_id::text=:'t'),
top AS (SELECT tedarikci_kodu, tedarikci_adi, -tedarikci_bakiye borc
          FROM bi_cari_bakiye WHERE tenant_id::text=:'t' AND export_date=(SELECT d FROM mc) AND tedarikci_bakiye<0
         ORDER BY tedarikci_bakiye ASC LIMIT 3),
al AS (SELECT tedarikci_kodu, sum(satir_kdv_haric) haric, sum(satir_kdv_dahil) dahil
         FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND fatura_tarihi>=CURRENT_DATE-365 GROUP BY 1)
SELECT t.tedarikci_adi, round(t.borc/1e6,1) borc_m,
       round(al.haric/1e6,1) alim_haric_m, round(al.dahil/1e6,1) alim_dahil_m
  FROM top t LEFT JOIN al ON al.tedarikci_kodu=t.tedarikci_kodu ORDER BY t.borc DESC;

\echo '===== 4) KANON view — DSO/DPO içindeki bazlar (alacak & borç dahil mi, akış hariç mi) ====='
SELECT round(ar_net/1e6,1) alacak_m, round(net_satis_lastik/1e6,1) net_satis_m,
       round(ap_borc/1e6,1) borc_m, round(smm/1e6,1) smm_m, dso, dpo
  FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'t';
