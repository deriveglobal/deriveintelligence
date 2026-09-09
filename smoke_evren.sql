-- Derive · EVREN server smoke: evren_desen(tenant) ≡ 'LASTIK%' KRB icin (esit olmali)
\pset pager off
\set KRB 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
SELECT 'bi_satis_faturalari' t,
  (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text=:'KRB' AND grup_adi LIKE 'LASTIK%') literal,
  (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text=:'KRB' AND grup_adi LIKE evren_desen(tenant_id::text)) fonksiyon
UNION ALL SELECT 'bi_stok_durumu',
  (SELECT count(*) FROM bi_stok_durumu WHERE tenant_id::text=:'KRB' AND grup_adi ILIKE 'LASTIK%'),
  (SELECT count(*) FROM bi_stok_durumu WHERE tenant_id::text=:'KRB' AND grup_adi ILIKE evren_desen(tenant_id::text));

\echo '=== literal = fonksiyon ise (t) esdegerdir ==='
SELECT (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text=:'KRB' AND grup_adi LIKE 'LASTIK%')
     = (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text=:'KRB' AND grup_adi LIKE evren_desen(tenant_id::text)) AS esdeger_satis;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_EVREN_SERVER_V1',
       'server_container.mjs 66 grup_adi (I)LIKE LASTIK% -> evren_desen(alias.tenant_id) (self-verify tenant_id-in-scope, FLAG=0)',
       'Faz C: endpoint SQL is-evreni per-tenant. evren_desen KRB=LASTIK% -> sifir davranis degisikligi (esdeger smoke ile kanitli). grup_adi IN(...) 8 site AYRI.',
       '{"site":66,"yontem":"self-verifying regex patch","IN_site_kalan":8,"prompt_email":"ayri build"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_EVREN_SERVER_V1');
\echo '=== smoke SONU ==='
