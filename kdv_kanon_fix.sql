-- KDV_TUTARLILIK_V1 — v_finans_ticari_sermaye: DSO/DPO/CCC KDV-tutarli.
-- Bulgu (kanitli): akis (net_satis/SMM) KDV-HARIC, bakiye (alacak/borc) KDV-DAHIL -> DSO/DPO ~%17,5 sisik.
-- Fix: DSO/DPO'da bakiyeyi tenant'in OLCULEN KDV faktoruyle (bi_tedarikci dahil/haric) net'e cek. Sabit sayi YOK.
-- DIO tutarli (stok+SMM haric), dokunulmaz. ar_net/ap_borc/twc ham (dahil) kalir -> ₺ kartlari gercek tutari gosterir.
SET lock_timeout = '15s';

CREATE OR REPLACE VIEW v_finans_ticari_sermaye AS
 WITH maxay AS (SELECT tenant_id, max(ay) AS m FROM bi_marj_atom GROUP BY tenant_id),
      mr AS (SELECT tenant_id, max(export_date) AS d FROM bi_musteri_risk GROUP BY tenant_id),
      ms AS (SELECT tenant_id, max(export_date) AS d FROM bi_stok_durumu GROUP BY tenant_id),
      mc AS (SELECT tenant_id, max(export_date) AS d FROM bi_cari_bakiye GROUP BY tenant_id),
      flow AS (SELECT a.tenant_id, sum(a.ciro) AS net_satis, sum(a.ciro - a.brut_kar) AS smm, sum(a.brut_kar) AS brut_kar
                 FROM bi_marj_atom a JOIN maxay ON maxay.tenant_id = a.tenant_id
                WHERE a.ay > (maxay.m - '1 year'::interval) GROUP BY a.tenant_id),
      ar AS (SELECT r.tenant_id, sum(GREATEST(r.hesap_bakiyesi, 0::numeric)) AS ar_net
               FROM bi_musteri_risk r JOIN mr ON mr.tenant_id = r.tenant_id AND r.export_date = mr.d
              WHERE r.musteri_mi AND r.grup !~~* '%TEDAR%'::text GROUP BY r.tenant_id),
      stok AS (SELECT s.tenant_id, sum(s.toplam_deger) AS stok_deger
                 FROM bi_stok_durumu s JOIN ms ON ms.tenant_id = s.tenant_id AND s.export_date = ms.d
                WHERE s.grup_adi ~~* 'LASTIK%'::text GROUP BY s.tenant_id),
      ap AS (SELECT c.tenant_id, sum(CASE WHEN c.tedarikci_bakiye < 0 THEN - c.tedarikci_bakiye ELSE 0 END) AS ap_borc
               FROM bi_cari_bakiye c JOIN mc ON mc.tenant_id = c.tenant_id AND c.export_date = mc.d GROUP BY c.tenant_id),
      kdv AS (SELECT tenant_id, sum(satir_kdv_dahil) / NULLIF(sum(satir_kdv_haric), 0) AS f
                FROM bi_tedarikci_faturalari
               WHERE satir_kdv_haric > 0 AND fatura_tarihi >= CURRENT_DATE - 365 GROUP BY tenant_id),
      netgec AS (SELECT v.tenant_id, sum(v.net_gecikmis) AS net_gecikmis FROM v_net_gecikmis_musteri v GROUP BY v.tenant_id),
      tumciro AS (SELECT f.tenant_id, sum(f.satir_tutar) AS toplam_ciro
                    FROM bi_satis_faturalari f JOIN maxay ON maxay.tenant_id::text = f.tenant_id
                   WHERE f.satir_tutar > 0::numeric AND f.fatura_tarihi >= (maxay.m - '11 mons'::interval) AND f.fatura_tarihi < (maxay.m + '1 mon'::interval)
                   GROUP BY f.tenant_id)
 SELECT flow.tenant_id,
    ar.ar_net,
    stok.stok_deger,
    ap.ap_borc,
    flow.net_satis AS net_satis_lastik,
    tumciro.toplam_ciro AS ciro_tum_sirket,
    flow.smm,
    flow.brut_kar,
    round(100.0 * flow.brut_kar / NULLIF(flow.net_satis, 0::numeric), 1) AS marj_pct,
    netgec.net_gecikmis,
    round(netgec.net_gecikmis * 0.5) AS finansman_yil,
    round(ar.ar_net / COALESCE(kdv.f, 1) / NULLIF(flow.net_satis, 0::numeric) * 365::numeric) AS dso,
    round(stok.stok_deger / NULLIF(flow.smm, 0::numeric) * 365::numeric) AS dio,
    round(ap.ap_borc / COALESCE(kdv.f, 1) / NULLIF(flow.smm, 0::numeric) * 365::numeric) AS dpo,
    round(ar.ar_net / COALESCE(kdv.f, 1) / NULLIF(flow.net_satis, 0::numeric) * 365::numeric
          + stok.stok_deger / NULLIF(flow.smm, 0::numeric) * 365::numeric
          - ap.ap_borc / COALESCE(kdv.f, 1) / NULLIF(flow.smm, 0::numeric) * 365::numeric) AS ccc,
    round(ar.ar_net + stok.stok_deger - ap.ap_borc) AS twc,
    round(100.0 * (ar.ar_net + stok.stok_deger - ap.ap_borc) / NULLIF(flow.net_satis, 0::numeric), 1) AS bagli_sermaye_oran
   FROM flow
     JOIN ar ON ar.tenant_id = flow.tenant_id
     JOIN stok ON stok.tenant_id = flow.tenant_id
     JOIN ap ON ap.tenant_id = flow.tenant_id
     LEFT JOIN kdv ON kdv.tenant_id = flow.tenant_id
     LEFT JOIN netgec ON netgec.tenant_id = flow.tenant_id
     LEFT JOIN tumciro ON tumciro.tenant_id = flow.tenant_id::text;

\echo '===== TEST — KDV-tutarli DSO/DPO/CCC ====='
SELECT (SELECT round(sum(satir_kdv_dahil)/NULLIF(sum(satir_kdv_haric),0),3) FROM bi_tedarikci_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND satir_kdv_haric>0 AND fatura_tarihi>=CURRENT_DATE-365) kdv_faktor,
       dso, dio, dpo, ccc
  FROM v_finans_ticari_sermaye WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'KDV_TUTARLILIK_V1',
 'v_finans_ticari_sermaye: DSO/DPO/CCC KDV-tutarli hale getirildi. Akis (net_satis/SMM) KDV-haric, bakiye (alacak/borc) KDV-dahil idi -> DSO/DPO ~%17,5 sisikti. Fix: DSO/DPO''da bakiye tenant''in OLCULEN KDV faktoruyle (bi_tedarikci dahil/haric ~1,175) net''e cekildi. Sabit sayi yok (cok-tenant). DIO dokunulmadi (stok+SMM zaten haric). ar_net/ap_borc/twc ham (dahil) kaldi -> ₺ kartlari gercek tutari gosterir.',
 'Fatih "revenue/cost KDV haric mi dahil mi" -> kanitlandi: satis satir_tutar=miktar×birim_fiyat (haric), alim satir_kdv_haric kullaniliyor (haric), cari bakiye dahil. DSO 100->~85, DPO 239->~203 (KDV kadar). Ayrica chip''lere KDV bazi etiketi (Part B).',
 '{"marker":"KDV_TUTARLILIK_V1","kanit":{"satis":"satir_tutar=miktar*birim_fiyat -> haric","alim":"kdv_haric kolonu","bakiye":"cari -> dahil"},"faktor":"olculen bi_tedarikci dahil/haric (~1,175), tenant basina","degisen":["dso","dpo","ccc"],"dokunulmadi":["dio","ar_net","ap_borc","twc"],"not":"AR satis-KDV proxy=alim-KDV (satista kdv kolonu yok, DSO farki ihmal)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='KDV_TUTARLILIK_V1');
