-- Derive · Taksonomi 2b PREP: kategori_sezon(p,t) overload (server 2-arg cagirabilsin).
-- Override yoksa tenant-less kategori_sezon(p) (KRB birebir). 'SEZON:' prefix ile tenant_taksonomi.
\pset pager off
CREATE OR REPLACE FUNCTION kategori_sezon(p text, t uuid) RETURNS text
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE((SELECT segment FROM tenant_taksonomi WHERE tenant_id=t AND kategori='SEZON:'||p),
                    kategori_sezon(p))
$$;
\echo '=== KANIT: kategori_sezon 1-arg = 2-arg tum KRB kategorileri (t bekleriz) ==='
SELECT bool_and(kategori_sezon(kategori) = kategori_sezon(kategori,'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid)) AS esdeger
FROM (SELECT DISTINCT kategori FROM bi_satis_faturalari
      WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND kategori IS NOT NULL) q;
\echo '=== PREP SONU ==='
