-- FINANS_WIN_CLIENT_V1 fingerprint. Konteyner marker sonrasi.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_WIN_CLIENT_V1',
 'finans.html client: zaman secici artik akis kartlarini pencereler (loadFin(win) -> /api/bi/finans/oda?win, secici degisince re-fetch). 4 eksik metrik kart doldu: fiyat sizintisi/olculen tahsilat/olu stok/siparis bekleyen (rozet canli). Akis kartlarinin DONEM etiketi secilen doneme guncellenir. Ust seritte akis-vs-bilanco ayrimi netlestirildi (bilanco+dongu daima anlik).',
 'Fatih finans modulu derin incelemesi: (1) zaman secici her sekmede ama saygi gormuyordu -> akis pencerelendi, bilanco/dongu anlik rozetlendi. (2) 5 placeholder karttan 4u gercek verili -> baglandi (server FINANS_WIN_V1 + client). Tesvik-sonrasi marj veri-bloklu acik kaldi.',
 '{"dosya":"shells/finans.html","baglanan_kart":["gSizinti","gOlculen","gOluStok","gSiparis"],"secici":"loadFin(win) re-fetch","donem_etiket":"akis kartlari secilen doneme","marker":"FINANS_WIN_CLIENT_V1","server":"FINANS_WIN_V1","acik":"tesvik-sonrasi marj (veri)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_WIN_CLIENT_V1');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='FINANS_WIN_CLIENT_V1';
