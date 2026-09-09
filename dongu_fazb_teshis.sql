-- DÖNGÜ FAZ B — TEŞHİS (READ-ONLY). Yamadan ÖNCE: her DSO yüzeyinin CANLI sayısını yan yana gör.
-- Amaç: "bi_metrik_gecmis 'dso' = ölçülen tahsilat hızı (~27) mı, bilanço-tabanlı (100) mı?" çatalını VERİYLE kes.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo '===== 1) metrik_snapshot_al fonksiyon tanimi (dso nasil hesaplaniyor?) ====='
SELECT pg_get_functiondef(p.oid)
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE p.proname='metrik_snapshot_al' AND n.nspname='public';

\echo '===== 2) bi_metrik_gecmis sirket dso serisi (son 6 ay) — KOKPIT vitals + trend + finansal-icgoru + finans-seri BUNU okuyor ====='
SELECT to_char(donem,'YYYY-MM') ay, round(deger,1) dso_seri, guven
  FROM bi_metrik_gecmis
 WHERE tenant_id::text=:'t' AND boyut_tipi='sirket' AND metrik='dso' AND periyot='ay'
 ORDER BY donem DESC LIMIT 6;

\echo '===== 3) KANON (v_finans_ticari_sermaye) — bilanco-tabanli, olmasi gereken tek sayi ====='
SELECT round(dso,0) dso_kanon, round(dio,0) dio_kanon, round(dpo,0) dpo_kanon, round(ccc,0) ccc_kanon,
       round(ar_net/1e6,1) ar_m, round(net_satis_lastik/1e6,1) net_satis_m, round(smm/1e6,1) smm_m
  FROM v_finans_ticari_sermaye WHERE tenant_id=:'t'::uuid;

\echo '===== 4) /api/bi/ana BUGUN dso_gun proxy (risk / gunluk-ciro) — bu yuzeyi kanona baglayacagiz ====='
WITH risk AS (SELECT COALESCE(sum(hesap_bakiyesi),0) r FROM bi_musteri_risk WHERE tenant_id::text=:'t' AND COALESCE(musteri_mi,true)),
     ciro AS (SELECT COALESCE(sum(satir_tutar),0)/365.0 g FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND ebat IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-365)
SELECT round(risk.r/1e6,1) risk_m, round(ciro.g*365/1e6,1) yillik_ebat_ciro_m,
       round(risk.r/NULLIF(ciro.g,0)) dso_gun_bugun
  FROM risk, ciro;

\echo '===== 5) dso-icgoru sinif-bazli (bakiye/gunluk-satis) — toplami kanona yakin mi? ====='
WITH cls AS (SELECT f.musteri_kodu kod, CASE WHEN COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)='PSR'),0) >= COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)<>'PSR'),0) THEN 'TUK' ELSE 'TIC' END sinif
             FROM bi_satis_faturalari f JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date
            WHERE f.tenant_id::text=:'t' AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months' AND f.satir_tutar>0 GROUP BY 1),
     rev AS (SELECT SUM(f.satir_tutar) rev12 FROM bi_satis_faturalari f WHERE f.tenant_id::text=:'t' AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months' AND f.satir_tutar>0),
     r1 AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, GREATEST(hesap_bakiyesi,0) bak, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=:'t' ORDER BY muhatap_kodu, export_date DESC),
     bak AS (SELECT SUM(r.bak) bakiye FROM r1 r WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%')
SELECT round(bak.bakiye/1e6,1) bakiye_m, round(rev.rev12/1e6,1) rev12_m,
       round(bak.bakiye/NULLIF(rev.rev12/365.0,0)) dso_icgoru_toplam
  FROM bak, rev;

\echo '===== 6) cash-cycle-history & financial-perspective vade DSO (ort vade_tarihi-fatura_tarihi, son 3 ay) — vade proxy (ayri lens) ====='
SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay,
       round(avg((vade_tarihi-fatura_tarihi)) FILTER (WHERE vade_tarihi>fatura_tarihi)::numeric,1) vade_dso
  FROM bi_satis_faturalari
 WHERE tenant_id::text=:'t' AND fatura_tarihi>=date_trunc('month',now())-INTERVAL '3 months' AND fatura_tarihi<date_trunc('month',now())
 GROUP BY 1 ORDER BY 1;
