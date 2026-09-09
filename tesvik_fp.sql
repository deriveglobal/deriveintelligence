INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_TESVIK_WIN_V1',
 'Finans oda /api/bi/finans/oda JSON''una "markalardan kazanilan tesvik/prim" eklendi (tesvik.tutar/satir). Kaynak: bi_satis_faturalari kategori IN (DESTEK BEDELI, TUKETICI PRIM), YALNIZ muhatap=TEDARIKCI (bi_musteri_risk.grup ILIKE %TEDAR%). fatura_tarihi penceresi ?win seciciye yanit verir (bu ay/3/6/12/yil basi).',
 'Fatih: Karlilik penceresine kazanilan tesvik chip''i, zaman secici saygili. Muhatap teshisi: DESTEK BEDELI 32,08M (tedarikci 22,42 + musteri 9,67) + TUKETICI PRIM 10,32M (tedarikci 10,31). Karar: YALNIZ tedarikci = markalardan kazanilan (~32,7M/12ay, Brisa/Bridgestone + OLT/Continental); musteriye kesilen destek (İSB toptan, Rekor filo) HARIC — ters yon, kazanc degil.',
 '{"metrik":"kazanilan_tesvik","kaynak":"bi_satis_faturalari","kategori":["DESTEK BEDELİ","TÜKETİCİ PRİM"],"filtre":"muhatap=TEDARIKCI (bi_musteri_risk.grup ILIKE %TEDAR%)","pencere":"fatura_tarihi ?win","tedarikci_12ay_m":32.7,"marker":"FINANS_TESVIK_WIN_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_TESVIK_WIN_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_TESVIK_CHIP_V1',
 'Finans oda Karlilik gorunumune "Kazanilan Tesvik · markalardan" karti (id=g2Tesvik) eklendi. Bloklu "Net Marj (tesvik sonrasi)" kartinin yanina: biri markalardan GERCEKTEN kazanilan (canli), digeri tesvik-sonrasi net marj (hala bloklu). Statik kart .then''de oda.tesvik.tutar ile dolar; DONEM etiketi mevcut _WLBL dongusune katildi -> secili doneme uyar.',
 'Yer secimi Fatih: once Nakit Yolculugu dusunuldu, sonra "Karlilik penceresi dogru yer" -> tesvik bir karlilik/akis kalemi (prim maliyeti dusurmuyor, ciro olarak faturalaniyor -> efektif marji artirir), nakit-dongusu degil. Karlilik akis kartlari (net satis/SMM/brut kar) zaten pencereleniyor; tesvik dogal olarak yanlarina.',
 '{"kart":"g2Tesvik","gorunum":"karlilik (data-v=kar)","doldurma":".then oda.tesvik.tutar","donem":"_WLBL dongusu (secili donem)","marker":"FINANS_TESVIK_CHIP_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_TESVIK_CHIP_V1');

SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim IN ('FINANS_TESVIK_WIN_V1','FINANS_TESVIK_CHIP_V1') ORDER BY adim;
