-- ============================================================================
-- NET GECİKMİŞ KANONU — v_net_gecikmis_musteri (tek kaynak, çok-tenant, müşteri-kırılımlı)
-- Tanım: son export · müşteri başına (toplanmış) · müşteri_mi & TEDAR-dışı ·
--        tedarikçi mahsubu LEAST(tedarikci_bakiye,0) (yalnız bizim borç) · müşteri bazında 0'a floor.
-- Ekranlar (finans/kokpit/harita/oda) BUNU okuyacak — brüt de net de burada.
-- Additive: yeni view; hiçbir şeyi bozmaz. Calistirma:
--   cat kanon_net_gecikmis_view.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

CREATE OR REPLACE VIEW v_net_gecikmis_musteri AS
WITH sonr AS (
  SELECT tenant_id, max(export_date) d FROM bi_musteri_risk GROUP BY tenant_id
),
sonc AS (
  SELECT tenant_id, max(export_date) d FROM bi_cari_bakiye GROUP BY tenant_id
),
risk AS (
  SELECT r.tenant_id, r.muhatap_kodu kod,
         max(r.muhatap_adi) ad,
         sum(r.vadesi_gecmis) vg,
         bool_or(r.musteri_mi) musteri_mi,
         max(COALESCE(NULLIF(TRIM(r.grup),''),'')) grup
  FROM bi_musteri_risk r
  JOIN sonr ON sonr.tenant_id=r.tenant_id AND r.export_date=sonr.d
  GROUP BY r.tenant_id, r.muhatap_kodu
),
cb AS (
  SELECT c.tenant_id, c.musteri_kodu, sum(LEAST(c.tedarikci_bakiye,0)) borc
  FROM bi_cari_bakiye c
  JOIN sonc ON sonc.tenant_id=c.tenant_id AND c.export_date=sonc.d
  GROUP BY c.tenant_id, c.musteri_kodu
)
SELECT risk.tenant_id,
       risk.kod  AS muhatap_kodu,
       risk.ad   AS muhatap_adi,
       risk.grup,
       GREATEST(risk.vg,0)                                   AS brut_gecikmis,
       COALESCE(cb.borc,0)                                   AS tedarikci_mahsup,
       GREATEST(risk.vg + COALESCE(cb.borc,0),0)             AS net_gecikmis
  FROM risk
  LEFT JOIN cb ON cb.tenant_id=risk.tenant_id AND cb.musteri_kodu=risk.kod
 WHERE risk.musteri_mi AND risk.grup NOT ILIKE '%TEDAR%';

-- DOĞRULA 1: KRB toplam (kanon) — beklenen net 53,4M / brüt 86,3M / 593 gecikmiş
SELECT round(sum(net_gecikmis)/1e6,1)  net_M,
       round(sum(brut_gecikmis)/1e6,1) brut_M,
       count(*) FILTER (WHERE net_gecikmis>0) gecikmis_musteri
FROM v_net_gecikmis_musteri WHERE tenant_id::text=:T;

-- DOĞRULA 2: eski view (yanlış, 55,3) ile fark — kanona geçince finans core düzelir
SELECT round((SELECT net_gecikmis FROM v_finans_ticari_sermaye WHERE tenant_id=:T::uuid)/1e6,1) eski_view_55,
       round((SELECT sum(net_gecikmis) FROM v_net_gecikmis_musteri WHERE tenant_id::text=:T)/1e6,1) kanon_53;

-- DOĞRULA 3: en yüksek 8 gecikmiş müşteri (top-N ekranları buradan okuyacak)
SELECT muhatap_adi, round(net_gecikmis/1e6,1) net_M
FROM v_net_gecikmis_musteri WHERE tenant_id::text=:T AND net_gecikmis>0
ORDER BY net_gecikmis DESC LIMIT 8;
