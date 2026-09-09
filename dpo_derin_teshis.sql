-- DPO 239 DERİN teşhis (READ-ONLY) — kime borçluyuz, netleşince ne kalıyor, gerçek mi.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '===== 1) EN BÜYÜK 15 BORÇ — tedarikçi bakiye + müşteri bakiye (bize borcu) + net pozisyon ====='
SELECT tedarikci_adi,
       round(tedarikci_bakiye/1e6,1) ted_bakiye_m,
       round(musteri_bakiye/1e6,1)   mus_bakiye_m,
       round(net_pozisyon/1e6,1)     net_pozisyon_m
  FROM bi_cari_bakiye
 WHERE tenant_id::text=:'t' AND export_date=(SELECT max(export_date) FROM bi_cari_bakiye WHERE tenant_id::text=:'t')
   AND tedarikci_bakiye < 0
 ORDER BY tedarikci_bakiye ASC LIMIT 15;

\echo '===== 2) BRÜT borç vs NET borç (net_pozisyon mahsuplu) ====='
SELECT round(sum(-LEAST(tedarikci_bakiye,0))/1e6,1)      brut_borc_m,
       round(sum(-LEAST(net_pozisyon,0))/1e6,1)          net_borc_m,
       round(sum(GREATEST(net_pozisyon,0))/1e6,1)        bize_net_borclu_m
  FROM bi_cari_bakiye
 WHERE tenant_id::text=:'t' AND export_date=(SELECT max(export_date) FROM bi_cari_bakiye WHERE tenant_id::text=:'t');

\echo '===== 3) DPO/CCC — brüt vs net borç (view SMM aynen: smm = ap_borc*365/dpo) ====='
WITH v AS (SELECT dso, dio, dpo, ccc, ap_borc, ap_borc*365.0/NULLIF(dpo,0) smm FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'t'),
b AS (SELECT sum(-LEAST(net_pozisyon,0)) net_borc FROM bi_cari_bakiye WHERE tenant_id::text=:'t' AND export_date=(SELECT max(export_date) FROM bi_cari_bakiye WHERE tenant_id::text=:'t'))
SELECT v.dso, v.dio, v.dpo dpo_brut, v.ccc ccc_brut,
       round(b.net_borc/NULLIF(v.smm,0)*365) dpo_net,
       round(v.dso + v.dio - b.net_borc/NULLIF(v.smm,0)*365) ccc_net
  FROM v, b;

\echo '===== 4) EN BÜYÜK 3 BORÇ TEDARİKÇİSİ — borç vs 12 ay ALIM → ima edilen ödeme günü ====='
WITH top AS (SELECT tedarikci_kodu, tedarikci_adi, -tedarikci_bakiye borc
               FROM bi_cari_bakiye WHERE tenant_id::text=:'t' AND export_date=(SELECT max(export_date) FROM bi_cari_bakiye WHERE tenant_id::text=:'t')
                AND tedarikci_bakiye<0 ORDER BY tedarikci_bakiye ASC LIMIT 3)
SELECT t.tedarikci_adi, round(t.borc/1e6,1) borc_m,
       round(COALESCE(a.alim,0)/1e6,1) alim_12ay_m,
       round(t.borc / NULLIF(a.alim,0) * 365) ima_odeme_gun
  FROM top t
  LEFT JOIN (SELECT tedarikci_kodu, sum(satir_kdv_haric) alim FROM bi_tedarikci_faturalari
              WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 AND fatura_tarihi>=CURRENT_DATE-365 GROUP BY 1) a
    ON a.tedarikci_kodu=t.tedarikci_kodu
 ORDER BY t.borc DESC;

\echo '===== 5) export tarihi + kaç kayıt (snapshot güncel mi) ====='
SELECT max(export_date) son_export, count(*) FILTER (WHERE export_date=(SELECT max(export_date) FROM bi_cari_bakiye WHERE tenant_id::text=:'t')) satir
  FROM bi_cari_bakiye WHERE tenant_id::text=:'t';
