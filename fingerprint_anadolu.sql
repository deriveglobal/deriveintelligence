-- ============================================================
-- Derive · FINGERPRINT — cok-tenant agnostik + Anadolu demo milestone
-- Idempotent (WHERE NOT EXISTS adim uzerinden). Yalniz build-log yazar.
-- Yeni tablo/endpoint/fonksiyon YOK -> bi_yetenek INSERT gerekmez.
-- ============================================================

-- 1) marj_fact per-tenant (KOD marker: erp_ingest.py MARJFACT_MULTITENANT_V1)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MARJFACT_MULTITENANT_V1',
       'erp_ingest turet(): bi_marj_fact global DROP/RENAME -> per-tenant DELETE+INSERT (mutabakat referansi da per-tenant)',
       'Cok-tenant: bir tenant yuklemesi diger tenantlarin marj_fact satirlarini silmesin',
       '{"dosya":"erp_ingest.py","marker":"MARJFACT_MULTITENANT_V1","kanit":{"KRB_marj_fact":28968,"ANADOLU_marj_fact":4724}}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MARJFACT_MULTITENANT_V1');

-- 2) kimlik agnostik v1 (KOD marker: server_container.mjs TENANT_KIMLIK_AGNOSTIK_V1)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'TENANT_KIMLIK_AGNOSTIK_V1',
       '4 yardimci AI SYS prompt "KRB" literali -> calisma-aninda tenant adi (platform_tenants.name / session.tenantName)',
       'Kimlik agnostik: her tenant CEO/analist asistani kendi adiyla konussun',
       '{"dosya":"server_container.mjs","marker":"TENANT_KIMLIK_AGNOSTIK_V1","site":4,"not":"alan-ifadesi (lastik toptancisi) Faz C"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TENANT_KIMLIK_AGNOSTIK_V1');

-- 3) kimlik agnostik a2 (KOD marker: server_container.mjs TENANT_KIMLIK_AGNOSTIK_A2)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'TENANT_KIMLIK_AGNOSTIK_A2',
       'CEO selfCtx''ten bi_insa_gunlugu (KRB platform insa gecmisi) otomatik enjeksiyonu cikarildi',
       'Her tenant CEO''su KRB''nin insa kaydini "hatirlamasin"; bi_yetenek listesi (platform-genel) kalir',
       '{"dosya":"server_container.mjs","marker":"TENANT_KIMLIK_AGNOSTIK_A2"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TENANT_KIMLIK_AGNOSTIK_A2');

-- 4) cron cok-tenant (rep_ozellik / sinyal / rep_gelisim tenant dongusu)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'CRON_MULTITENANT_V1',
       'Gunluk turetme cron''lari (rep_ozellik, sinyal_motor, sinyal_ek1, rep_gelisim) tum tenant''lari donguler',
       'Onceki hal: cron''lar tek-tenant (implicit KRB) calisiyordu -> yeni tenant''lar gunluk turetme almazdi',
       '{"scriptler":["rep_ozellik_cron.sh","sinyal_motor_cron.sh","sinyal_ek1_cron.sh"],"desen":"DO $ FOR r IN SELECT DISTINCT tenant_id ... LOOP"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='CRON_MULTITENANT_V1');

-- 5) Anadolu demo tenant ucdan uca canli (DATA milestone)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'ANADOLU_DEMO_TENANT_V1',
       'Anadolu Lastik ve Otomotiv A.S. demo tenant ucdan uca canli: 6+1 ERP feed + marj_fact + marj_atom (kanon) + DSO/DIO/DPO/CCC snapshot',
       'Pazarlama demo tenant''i + cok-tenant izolasyon QA (KRB verisi bozulmadan ikinci tenant yasar)',
       ('{"tenant_id":"42822870-4ea3-424d-a16f-50b91afca32c",'
        '"marj_atom":460,"maliyet_kaynak":"donem","marj_pct_atom":8.1,'
        '"v_finans":{"dso":20,"dio":6,"dpo":15,"ccc":11,"marj_pct":8.0},'
        '"feed":["satis","tedarikci","alacak_yaslandirma","tahsilat","cari_bakiye","stok_anlik","stok_hareket(acilis+mal_girisi+satis)"],'
        '"izolasyon_kaniti":{"KRB_marj_atom":15631,"KRB_marj_fact":28968}}')::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='ANADOLU_DEMO_TENANT_V1');

-- DOGRULAMA: son 8 build-log satiri
SELECT adim, ts::date, ne FROM bi_insa_gunlugu ORDER BY ts DESC LIMIT 8;
