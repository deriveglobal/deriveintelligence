-- ============================================================================
-- NET GECİKMİŞ TEŞHİS — üç değer (view 55,7 / kokpit 54,9 / risk 53,4) neden ayrışıyor?
-- Aynı tabandan (bi_musteri_risk + bi_cari_bakiye) aday tanımları yan yana hesaplar.
-- Salt-okunur (SELECT). Calistirma:
--   cat net_gecikmis_tani.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 0) TAZELİK: kaç export günü, en son tarih, satır
SELECT count(DISTINCT export_date) export_gun, max(export_date) son_export, count(*) satir
FROM bi_musteri_risk WHERE tenant_id::text=:T;

-- 1) ADAY TANIMLAR — her muhatap EN SON export (DISTINCT ON), tek tabloda kıyas
WITH r AS (
  SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod,
         GREATEST(vadesi_gecmis,0) vg_floor, vadesi_gecmis vg_raw,
         musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup
  FROM bi_musteri_risk WHERE tenant_id::text=:T
  ORDER BY muhatap_kodu, export_date DESC
),
cb AS (
  SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc
  FROM bi_cari_bakiye WHERE tenant_id::text=:T GROUP BY musteri_kodu
)
SELECT
 round(sum(GREATEST(r.vg_floor+COALESCE(cb.borc,0),0)) FILTER (WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%')/1e6,1) A_oda_net_musteri_nonTEDAR_MAHSUPLU,
 round(sum(r.vg_floor) FILTER (WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%')/1e6,1)                                  B_brut_musteri_nonTEDAR,
 round(sum(r.vg_floor) FILTER (WHERE r.musteri_mi)/1e6,1)                                                                 C_brut_musteri_hepsi,
 round(sum(r.vg_floor)/1e6,1)                                                                                             D_brut_herkes_floor,
 round(sum(r.vg_raw)/1e6,1)                                                                                               E_brut_herkes_floorsuz,
 round(sum(GREATEST(r.vg_floor+COALESCE(cb.borc,0),0)) FILTER (WHERE r.musteri_mi)/1e6,1)                                 F_net_musteri_hepsi_MAHSUPLU
FROM r LEFT JOIN cb ON cb.musteri_kodu=r.kod;

-- 2) GLOBAL SON EXPORT (tek tarih snapshot) — DISTINCT ON yerine son tarihin satırları
WITH g AS (SELECT max(export_date) d FROM bi_musteri_risk WHERE tenant_id::text=:T)
SELECT round(sum(GREATEST(vadesi_gecmis,0)) FILTER (WHERE musteri_mi AND COALESCE(grup,'') NOT ILIKE '%TEDAR%')/1e6,1) G_globalson_brut_musteri_nonTEDAR,
       round(sum(GREATEST(vadesi_gecmis,0))/1e6,1) H_globalson_brut_herkes
FROM bi_musteri_risk WHERE tenant_id::text=:T AND export_date=(SELECT d FROM g);

-- 3) VIEW'İN KENDİ DEĞERİ + TANIMI (net_gecikmis kolonu nasıl hesaplanıyor?)
SELECT round(net_gecikmis/1e6,1) view_net_gecikmis_M FROM v_finans_ticari_sermaye WHERE tenant_id=:T::uuid;
SELECT pg_get_viewdef('v_finans_ticari_sermaye', true);
