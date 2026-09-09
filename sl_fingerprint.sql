\pset pager off
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SL_MULTITENANT_V1',
       'sl_connector cron cok-tenant: sl.d/*.env per-tenant (SL_TENANT/USER/PASS/BASE_URL); sl_connector_cron.sh dongusu',
       'Onceki: tek cron, tek sl.env (implicit KRB tenant + KRB SAP). Simdi per-tenant env; SL''siz tenant (Anadolu) otomatik atlanir. KRB kimlik/davranis degismedi.',
       '{"scriptler":["sl_setup.sh","sl_connector_cron.sh"],"dizin":"/opt/krb-assessment/sl.d","krb":"krb.env (mevcut creds + SL_TENANT/SL_BASE_URL explicit)","py_default_kaldirma":"server build batch''inde (SL_TENANT KRB default -> zorunlu)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SL_MULTITENANT_V1');
SELECT 'SL_MULTITENANT_V1 kaydedildi' AS durum;
