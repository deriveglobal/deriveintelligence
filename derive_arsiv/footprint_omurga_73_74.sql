-- omurga_73 + omurga_74 ayak izi -> bi_insa_gunlugu (DB ikizi). Idempotent (adim varsa atlar).
-- Calistir: docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < footprint_omurga_73_74.sql

INSERT INTO bi_insa_gunlugu (id, ts, adim, ne, neden, detay)
SELECT gen_random_uuid(), now(), 'omurga_73',
  'CAM-KOKPIT sunucuya baglandi: Finans odasinin ANA gorunumu. shells/kokpit.html (fetch) + GET /api/bi/kokpit (SPA baypas) + GET /api/bi/kokpit-data (trend/marka/segment/sezon/kanal/insights); bi.js finans->iframe, ciz_finans erken-return',
  'Cockpit prototipini (derive_cockpit_v2) canliya tasi; Fatih karari: cockpit finans odasinin ANA gorunumu olsun - zaten ayni metrikler',
  '{"route":["/api/bi/kokpit","/api/bi/kokpit-data"],"tuzaklar":{"spa":"/kokpit SPA yutuyor -> /api/bi/kokpit","auth":"getSessionUser -> requireModuleAccess(intelligence)","tip":"uuid=text -> tenant_id::text kaliplari"},"script":["patch_kokpit.py","patch_kokpit2.py","patch_kokpit3.py","patch_kokpit4.py"],"devir":"EK-13"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='omurga_73');

INSERT INTO bi_insa_gunlugu (id, ts, adim, ne, neden, detay)
SELECT gen_random_uuid(), now(), 'omurga_74',
  'Kokpit interaktif + tam canlilik: (A) duzen kaliciligi bi_kokpit_tercih + /api/bi/kokpit-layout; (B) bekleyen-duzeltme ogrenme dongusu bi_kokpit_duzeltme(durum=beklemede) + /api/bi/kokpit-duzeltme; (C) tum hardcoded sayilar veriden turetildi',
  'Duzen yenilemede sifirlaniyordu; Fatih: chip duzeltmesi = veri-dogrulugu/oz-ogrenme sinyali (sosyal degil), PENDING; Fatih ilkesi: hicbir yerde sabit sayi/ifade yok',
  '{"tablo":["bi_kokpit_tercih","bi_kokpit_duzeltme"],"route":["/api/bi/kokpit-layout","/api/bi/kokpit-duzeltme"],"duzeltme":"durum=beklemede; organizma tartar; otomatik uygulanmaz; adjudication=sonraki is","canlilik_fix":{"YENILEME_KANALI":"HATA duzeldi: kanal degil SEGMENT -%6,2","sirket_marj":"~10,4 -> ciro-agirlikli hesap","header":"PIYASA CANLI/ERP T-5G uydurma -> bagli degil/son ay","piyasa_radar":"129k/62k uydurma -> kaynak bagli degil, sayi uretmiyor"},"degismez":{"odalar":"KULLANICI YETKISI bazli (permissions.departments); client-toplu kaldirma yok","organizma":"hicbir yerde hardcoded sayi/ifade yok","duzeltme":"pending"},"park":"eski 6 departman odasi kaldirma - plan disi ertelendi; yapilirsa yetki bazli; patch_odalar.py devre-disi","script":["patch_kokpit5.py","kokpit.html"],"devir":"EK-13"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='omurga_74');

SELECT adim, ts FROM bi_insa_gunlugu WHERE adim IN ('omurga_73','omurga_74') ORDER BY adim;
