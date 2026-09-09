-- ============================================================================
-- STOK KANONU — v_stok_deger_kanon (tek kaynak, çok-tenant)
-- Tanım: bi_stok_durumu · en son export · grup_adi ILIKE 'LASTIK%' (gerçek lastik stoğu).
-- Ham toplam (~730,9M) yanıltıcı: %58'i yardımcı malzeme, sarf birim-maliyeti şişik.
-- Değer + SKU + kritik + sıfır stok, hepsi lastik-kapsamlı. Ekranlar bunu okur.
-- Calistirma: cat kanon_stok_view.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''
CREATE OR REPLACE VIEW v_stok_deger_kanon AS
WITH son AS (SELECT tenant_id, max(export_date) d FROM bi_stok_durumu GROUP BY tenant_id)
SELECT s.tenant_id,
       sum(s.toplam_deger)                                                          AS stok_deger,
       count(DISTINCT s.kalem_kodu)                                                 AS sku_sayisi,
       count(*) FILTER (WHERE s.eldeki_miktar <= s.min_stok AND s.min_stok > 0)     AS kritik_stok,
       count(*) FILTER (WHERE s.eldeki_miktar = 0)                                  AS sifir_stok
FROM bi_stok_durumu s JOIN son ON son.tenant_id=s.tenant_id AND s.export_date=son.d
WHERE s.grup_adi ILIKE 'LASTIK%'
GROUP BY s.tenant_id;

-- DOĞRULA: KRB lastik stok değeri (~276,7M bekle) vs ham (~730,9M)
SELECT round(stok_deger/1e6,1) kanon_lastik_M, sku_sayisi, kritik_stok, sifir_stok FROM v_stok_deger_kanon WHERE tenant_id::text=:T;
SELECT round(sum(toplam_deger)/1e6,1) ham_tum_M FROM bi_stok_durumu WHERE tenant_id::text=:T AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=:T);
