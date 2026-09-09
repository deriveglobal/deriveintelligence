-- ============================================================================
-- NET GECİKMİŞ TEŞHİS-2 — dedup gerçekten fark mı, ve ÖNERİLEN KANON değeri.
-- Salt-okunur. Calistirma:
--   cat net_gecikmis_tani2.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 1) SON export'ta müşteri başına satır sayısı (dedup fark yaratıyor mu?)
WITH son AS (SELECT max(export_date) d FROM bi_musteri_risk WHERE tenant_id::text=:T)
SELECT count(*) satir, count(DISTINCT muhatap_kodu) tekil_muhatap,
       round(count(*)::numeric/NULLIF(count(DISTINCT muhatap_kodu),0),2) satir_basi,
       max(k) max_satir_bir_muhatapta
FROM bi_musteri_risk r,
     LATERAL (SELECT count(*) k FROM bi_musteri_risk r2
              WHERE r2.tenant_id=r.tenant_id AND r2.export_date=r.export_date AND r2.muhatap_kodu=r.muhatap_kodu) x
WHERE r.tenant_id::text=:T AND r.export_date=(SELECT d FROM son);

-- 2) SON export'ta tedarikçi bakiyesi (cari) müşteri başına birden çok satır var mı? (join fan-out riski)
WITH sonc AS (SELECT max(export_date) d FROM bi_cari_bakiye WHERE tenant_id::text=:T)
SELECT count(*) satir, count(DISTINCT musteri_kodu) tekil, max(k) max_satir
FROM bi_cari_bakiye c,
     LATERAL (SELECT count(*) k FROM bi_cari_bakiye c2
              WHERE c2.tenant_id=c.tenant_id AND c2.export_date=c.export_date AND c2.musteri_kodu=c.musteri_kodu) x
WHERE c.tenant_id::text=:T AND c.export_date=(SELECT d FROM sonc);

-- 3) ÖNERİLEN KANON — son snapshot · müşteri başına TOPLANMIŞ · son-export mahsup · floor · müşteri&TEDAR-dışı
WITH sonr AS (SELECT max(export_date) d FROM bi_musteri_risk WHERE tenant_id::text=:T),
sonc AS (SELECT max(export_date) d FROM bi_cari_bakiye WHERE tenant_id::text=:T),
risk AS (
  SELECT muhatap_kodu kod, sum(vadesi_gecmis) vg,
         bool_or(musteri_mi) musteri_mi,
         max(COALESCE(NULLIF(TRIM(grup),''),'')) grup
  FROM bi_musteri_risk
  WHERE tenant_id::text=:T AND export_date=(SELECT d FROM sonr)
  GROUP BY muhatap_kodu
),
cb AS (
  SELECT musteri_kodu, sum(LEAST(tedarikci_bakiye,0)) borc
  FROM bi_cari_bakiye
  WHERE tenant_id::text=:T AND export_date=(SELECT d FROM sonc)
  GROUP BY musteri_kodu
)
SELECT
  round(sum(GREATEST(risk.vg,0)) FILTER (WHERE risk.musteri_mi AND risk.grup NOT ILIKE '%TEDAR%')/1e6,1)                              kanon_BRUT_M,
  round(sum(GREATEST(risk.vg + COALESCE(cb.borc,0),0)) FILTER (WHERE risk.musteri_mi AND risk.grup NOT ILIKE '%TEDAR%')/1e6,1)        kanon_NET_M,
  count(*) FILTER (WHERE risk.musteri_mi AND risk.grup NOT ILIKE '%TEDAR%' AND risk.vg>0)                                             gecikmis_musteri_sayisi
FROM risk LEFT JOIN cb ON cb.musteri_kodu=risk.kod;
