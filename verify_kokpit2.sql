-- ============================================================================
-- verify_kokpit2.sql — KOKPIT2 SAYI DOĞRULAMA (READONLY). Hiçbir şey yazmaz.
-- Her blok, kokpitteki sayıyı KAYNAK ERP tablolarından YENİDEN hesaplar; parantez
-- içindeki "(kokpit: ...)" ekrandaki değerdir — EŞLEŞMELİ. Eşleşmezse orada sorun var.
-- Çalıştırma (sunucuda):
--   docker exec -i krb-assessment-postgres psql -U <user> -d <db> < verify_kokpit2.sql
--   (user/db bilmiyorsan: docker exec krb-assessment-postgres env | grep -i pg  ya da  psql -l)
-- ============================================================================
\pset pager off
\timing off
SELECT id::text AS tid FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1 \gset
\echo '================ TENANT :tid ================'

\echo ''
\echo '===== 1) VERİ TAZELİĞİ (feed · son tarih · satır sayısı) — hepsi yakın tarihli olmalı ====='
SELECT 'musteri_risk'        AS feed, max(export_date)::text son_tarih, count(*) satir FROM bi_musteri_risk        WHERE tenant_id::text=:'tid'
UNION ALL SELECT 'cari_bakiye',       max(ingested_at)::date::text, count(*) FROM bi_cari_bakiye        WHERE tenant_id::text=:'tid'
UNION ALL SELECT 'satis_faturalari',  max(export_date)::text, count(*) FROM bi_satis_faturalari  WHERE tenant_id::text=:'tid'
UNION ALL SELECT 'tedarikci_fatura',  max(export_date)::text, count(*) FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'tid'
UNION ALL SELECT 'marj_atom (ay)',    max(ay)::text,          count(*) FROM bi_marj_atom         WHERE tenant_id::text=:'tid'
UNION ALL SELECT 'tahsilat',          max(export_date)::text, count(*) FROM bi_tahsilat          WHERE tenant_id::text=:'tid'
UNION ALL SELECT 'metrik_gecmis (ay)',max(donem)::text,       count(*) FROM bi_metrik_gecmis     WHERE tenant_id::text=:'tid' AND boyut_tipi='sirket';

\echo ''
\echo '===== 2) NET GECİKMİŞ + DSO (kokpit: net 54.9M · brüt 92.2M · mahsup 37.3M · DSO net 89) ====='
WITH rev AS (SELECT SUM(satir_tutar) FILTER (WHERE fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months') rev12
        FROM bi_satis_faturalari WHERE tenant_id::text=:'tid' AND satir_tutar>0),
risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup
        FROM bi_musteri_risk WHERE tenant_id::text=:'tid' ORDER BY muhatap_kodu, export_date DESC),
cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=:'tid' GROUP BY musteri_kodu),
j AS (SELECT r.hesap_bakiyesi, r.vg, COALESCE(cb.borc,0) borc FROM risk r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu
      WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%' AND GREATEST(r.hesap_bakiyesi,0) > 0),
ragg AS (SELECT SUM(GREATEST(hesap_bakiyesi,0)) bakiye, SUM(vg) brut, SUM(GREATEST(vg+borc,0)) net FROM j)
SELECT round(net/1e6,1)          AS "NET_GECIKMIS_Mn (54.9)",
       round(brut/1e6,1)         AS "BRUT_Mn (92.2)",
       round((brut-net)/1e6,1)   AS "MAHSUP_Mn (37.3)",
       round(bakiye/1e6,1)       AS "NET_ALACAK_Mn",
       round(bakiye*365.0/NULLIF((SELECT rev12 FROM rev),0),0) AS "DSO_NET_gun (89)"
FROM ragg;

\echo ''
\echo '===== 3) EN BÜYÜK NET GECİKMİŞ MÜŞTERİLER (kokpit: YEDİ OTO ~21.1M, FEVZİ ~6.3M, ...) ====='
WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, GREATEST(vadesi_gecmis,0) vg, musteri_mi, GREATEST(hesap_bakiyesi,0) bak, COALESCE(NULLIF(TRIM(grup),''),'') grup
        FROM bi_musteri_risk WHERE tenant_id::text=:'tid' ORDER BY muhatap_kodu, export_date DESC),
cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=:'tid' GROUP BY musteri_kodu)
SELECT COALESCE(NULLIF(TRIM(r.muhatap_adi),''),r.muhatap_kodu) AS musteri,
       round(GREATEST(r.vg+COALESCE(cb.borc,0),0)/1e6,1) AS net_gecikmis_Mn,
       round(r.vg/1e6,1) AS brut_Mn
FROM r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu
WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%' AND r.bak>0 AND GREATEST(r.vg+COALESCE(cb.borc,0),0)>0
ORDER BY GREATEST(r.vg+COALESCE(cb.borc,0),0) DESC LIMIT 6;

\echo ''
\echo '===== 4) PERFORMANS: Ciro · Adet · Brüt Marj ====='
\echo '-- Ciro son ay (bi_metrik_gecmis ciro_lastik) — kokpit "Ciro bu ay" ile eşleşmeli:'
SELECT to_char(donem,'YYYY-MM') ay, round(deger/1e6,1) AS ciro_Mn
FROM bi_metrik_gecmis WHERE tenant_id::text=:'tid' AND boyut_tipi='sirket' AND periyot='ay' AND metrik='ciro_lastik'
ORDER BY donem DESC LIMIT 2;
\echo '-- Adet bu ay (bi_satis_faturalari, sadece LASTİK) — kokpit "Adet bu ay":'
SELECT round(SUM(miktar))::bigint AS adet_bu_ay
FROM bi_satis_faturalari WHERE tenant_id::text=:'tid' AND miktar>0
  AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI')
  AND fatura_tarihi >= date_trunc('month', CURRENT_DATE);
\echo '-- Brüt marj 12 ay (bi_marj_atom, ciro-ağırlıklı) — kokpit "Brüt marj %":'
SELECT round(100.0*SUM(brut_kar)/NULLIF(SUM(ciro),0),1) AS brut_marj_pct
FROM bi_marj_atom WHERE tenant_id::text=:'tid' AND ay >= (CURRENT_DATE - INTERVAL '12 months');

\echo ''
\echo '===== 5) ORT. TAHSİLAT SÜRESİ (kokpit: ~31 gün) — bi_tahsilat tutar-ağırlıklı ====='
SELECT round(SUM(ort_tahsilat_suresi*toplam_tahsilat)/NULLIF(SUM(toplam_tahsilat),0),1) AS ort_gun_31,
       round(SUM(gec_odeme_orani*toplam_tahsilat)/NULLIF(SUM(toplam_tahsilat),0),1)     AS gec_oran,
       count(*) AS musteri
FROM bi_tahsilat WHERE tenant_id::text=:'tid' AND musteri_mi IS DISTINCT FROM false AND toplam_tahsilat>0;

\echo ''
\echo '===== 6) MARKA KIRILIMI ÖRNEĞİ (12 ay) — Performans marka drill ile karşılaştır ====='
SELECT marka, round(SUM(ciro)/1e6,1) AS ciro_Mn, SUM(adet)::bigint AS adet,
       round(100.0*SUM(brut_kar)/NULLIF(SUM(ciro),0),1) AS marj_pct
FROM bi_marj_atom WHERE tenant_id::text=:'tid' AND ay >= (CURRENT_DATE - INTERVAL '12 months')
GROUP BY marka HAVING SUM(ciro)>0 ORDER BY SUM(ciro) DESC LIMIT 8;

\echo ''
\echo '================ DOĞRULAMA BİTTİ — her bloğu kokpit ekranıyla karşılaştır ================'
