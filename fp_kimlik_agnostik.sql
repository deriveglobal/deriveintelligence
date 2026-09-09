INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'TENANT_KIMLIK_AGNOSTIK_V1',
       '4 yardimci AI SYS prompt: KRB literali -> calisma-aninda tenant adi',
       'Tenant-agnostik kimlik: yeni tenant AI kendini KRB sanmasin',
       '{"sites":["_bolumIcgoruUret","_sahaSesiUret","dso-icgoru","sahaSor"],"faz":"A","marker":"TENANT_KIMLIK_AGNOSTIK_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TENANT_KIMLIK_AGNOSTIK_V1');
