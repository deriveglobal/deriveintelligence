-- build log
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_EP_V1',
  'Rep satış-zekâ modülü "Portföyüm" canlı ucu: GET /api/saha/portfoyum',
  'Rep kendi defterini canlı görsün: dönem cirosu (bugün/hafta/bu-ay + geçen yıl aynı günler, 3/6ay/YTD), söz verilen ağırlıklı vade, gerçek ödeme davranışı, tahsilat riski; rep+tenant kapsamlı. Yönetici Kokpitinden ayrı modül.',
  '{"uc":["/api/saha/portfoyum"],"marker":"PORTFOYUM_EP_V1","kaynaklar":["saha_musteri","bi_satis_faturalari","master_musteri","bi_tahsilat","bi_musteri_risk"],"kapsam":"_sahaScopeSql","segment":"BG-NBD adim-2 (saha_satis_skor)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_EP_V1');

-- yeni endpoint yeteneği (footprint bunu getirmez)
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'saha_portfoyum','uc',
  'Rep kendi müşteri portföyü: canlı dönem cirosu (bugün/hafta/bu-ay + YoY aynı günler, 3/6ay/YTD), ağırlıklı vade + peşin%, gerçek ödeme (ort/son12 gecikme, geç%), tahsilat riski (limit/risk/vadesi geçmiş). Segment BG/NBD adım-2.',
  'GET /api/saha/portfoyum (Bearer, requireSahaAccess). Yanıt {rep,ozet,musteriler[]}. Kapsam: rep=kendi defteri.',
  'saha','canli','taslak',
  '{"uc":["/api/saha/portfoyum"],"marker":"PORTFOYUM_EP_V1","modul":"Portföyüm (rep)"}'::jsonb,
  true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_portfoyum');
