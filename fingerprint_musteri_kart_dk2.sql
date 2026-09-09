-- fingerprint_musteri_kart_dk2.sql — MUSTERI_KART_DK2_V1 (Slice 1) build-log. Idempotent.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_KART_DK2_V1',
       'Masaustu musteri karti (musteriDetay): dar 640px modal -> GENIS 1060px + 2-kolon layout (Slice 1, sadece duzen; id/handler degismedi)',
       'Kart masaustunde "telefon ekrani" gibi dar goruunuyordu (Fatih). Header full-genis, 2 kolon (kimlik+skor+finansal | fiyat+ziyaret+AI+lokasyon), aksiyonlar full-genis',
       '{"marker":"MUSTERI_KART_DK2_V1","shell":"saha_desktop.js","tur":"ui-layout","slice":1,"kalan":"olaylar timeline + edit + Not/Teklif/Ziyaret (Slice 2)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_DK2_V1');
SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='MUSTERI_KART_DK2_V1';
