-- FINGERPRINT — SAHA_SOR_V1 (bağlamsal sohbet motoru) + PORTFOYUM_ROOM_V4 (client 💬)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SAHA_SOR_V1',
       'Bağlamsal sohbet ucu POST /api/saha/ai/sor — her metrik/müşteri bağlamıyla rep beyinle konuşur; her soru+cevap saha_sinyal (kaynak_tip=ekran_sor) ile öğrenme izine akar',
       'Uygulama kendini eğitsin + kullanıcıyla hiç yapılmamış biçimde konuşsun (Fatih vizyonu); mevcut anthropic + saha_sinyal moat kullanıldı',
       '{"uc":"/api/saha/ai/sor","model":"claude-haiku-4-5-20251001","maliyet":"on-demand + haiku + client cache","ogrenme":"saha_sinyal kaynak_tip=ekran_sor","marker":"SAHA_SOR_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SAHA_SOR_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_ROOM_V4',
       'Portföyüm client: bağlamsal "💬 Sor/Konuş" bileşeni (sahaSor) — hero (portföyümü sor) + her segment + müşteri kartında; oturum-içi maliyet cache',
       'Rep herhangi bir metrik/müşteriden bağlamlı soru sorup aksiyon alsın',
       '{"dosya":"shells/saha.js","view":"vPortfoyum","fn":"sahaSor","uc":"/api/saha/ai/sor","marker":"PORTFOYUM_ROOM_V4"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_ROOM_V4');

INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, kanit, aktif, eklendi_at, guncellendi_at, son_gorulme)
SELECT 'saha_ai_sor', 'uc',
       'Bağlamsal AI sohbet: rep herhangi bir metrik/segment/müşteri hakkında soru sorar, bağlamı bilen kısa yanıt alır; etkileşim saha_sinyal ile öğrenmeye akar',
       'POST /api/saha/ai/sor {ekran,hedef_tip,hedef_ref,baglam,soru,gecmis} → haiku → {cevap} + saha_sinyal log',
       'saha', 'canli', 'taslak',
       '{"uc":["/api/saha/ai/sor"],"model":"haiku","marker":"SAHA_SOR_V1"}'::jsonb,
       true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_ai_sor');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim IN ('SAHA_SOR_V1','PORTFOYUM_ROOM_V4') ORDER BY adim;
