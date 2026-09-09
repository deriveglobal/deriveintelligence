INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'TENANT_KIMLIK_AGNOSTIK_A2',
       'CEO selfCtx: bi_insa_gunlugu (KRB insa gecmisi) tenant prompt cikarildi',
       'Tenant-agnostik: yeni tenant CEO asistani KRB insa kaydini hatirlamasin; bi_yetenek listesi kalir',
       '{"faz":"A2","kaldirilan":"insa_gunlugu auto-inject","korunan":"bi_yetenek","marker":"TENANT_KIMLIK_AGNOSTIK_A2"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TENANT_KIMLIK_AGNOSTIK_A2');
