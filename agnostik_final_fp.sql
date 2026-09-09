\pset pager off
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_EVREN_IN_V1',
       'server_container.mjs 7 site grup_adi IN(LASTIK TUKETICI,LASTIK TICARI) -> = ANY(evren_gruplar(alias.tenant_id))',
       'Faz C: exact-grup IN listesi per-tenant. evren_gruplar KRB=o iki grup -> sifir davranis degisikligi (esdeger kanitli). tamir/servis varyanti AYRI.',
       '{"site":7,"tamir_servis_kalan":1,"yontem":"self-verify tenant_id-in-scope"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_EVREN_IN_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PROMPT_EVREN_V1',
       'AI prompt is-tanimi "lastik toptancisi" -> evren_tanim (552/686 _tnEvren, 25152/27798 _evTanim helper); 30447 hardcoded "(KRB)" KIMLIK SIZINTISI kaldirildi',
       'Kimlik agnostik tamamlama: isim zaten agnostikti (kimlik V1); is-tanimi + 30447 KRB sizintisi kapatildi.',
       '{"prompt_site":5,"kimlik_sizinti_30447":"kaldirildi","helper":"_evTanim","not":"tire tenant metni birebir ayni"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PROMPT_EVREN_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SL_PY_DEFAULT_V1',
       'sl_connector.py SL_TENANT KRB default kaldirildi -> zorunlu (per-tenant cron gecirir)',
       'Son KRB-hardcode runtime .py; cron zaten SL_TENANT gecirdigi icin inert idi, temizlendi.',
       '{"dosya":"sl_connector.py","guard":"SL_TENANT zorunlu"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SL_PY_DEFAULT_V1');

\echo '=== IN esdeger RE-CHECK (build sonrasi; KRB esit olmali) ==='
SELECT (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI'))
     = (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND grup_adi = ANY(evren_gruplar(tenant_id::text))) AS esdeger;
\echo '=== FP SONU ==='
