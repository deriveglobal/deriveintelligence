\pset pager off
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'EMAIL_AGNOSTIK_V1',
       '5 hardcoded KRB e-posta -> rol/config: pilot_reps · ozel_karsilama_email · tenant_admin rol · cap-only · platform_owner-only',
       'Runtime e-posta literalleri kaldirildi; KRB config degerleri = mevcut -> davranis birebir. Kalan 2 = yorum (temizlendi).',
       '{"site":5,"config":["pilot_reps","ozel_karsilama_email"],"rol":["tenant_admin","cap","platform_owner"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='EMAIL_AGNOSTIK_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_TAKSONOMI_SERVER_V1',
       'server 26 SQL call-site kategori_segment/sezon(kategori) -> (kategori,$1::uuid) + kategori_sezon(p,t) overload + e-posta yorum temizligi',
       'Taksonomi per-tenant endpoint SQL. KRB override yok -> 2-arg=1-arg -> birebir. 1 site prompt-metni (SQL degil) kasitli birakildi.',
       '{"sql_site":26,"prose_atlanan":1,"overload":"kategori_sezon(text,uuid)","yorum_temizlik":2}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_TAKSONOMI_SERVER_V1');

\echo '=== KRB kategori_segment/sezon 1-arg = 2-arg (t bekleriz) ==='
SELECT bool_and(kategori_segment(kategori)=kategori_segment(kategori,'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid)
             AND kategori_sezon(kategori)=kategori_sezon(kategori,'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid)) AS esdeger
FROM (SELECT DISTINCT kategori FROM bi_satis_faturalari WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND kategori IS NOT NULL) q;
\echo '=== FP SONU ==='
