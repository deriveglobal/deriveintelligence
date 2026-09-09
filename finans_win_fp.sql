-- FINANS_WIN_V1 fingerprint. Konteyner marker=6 sonrasi.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_WIN_V1',
 '/api/bi/finans/oda ?win zaman secici: akis kartlari (net satis/smm/brut kar/marj/marka/catal/kar/sizinti) pencerelenir (bi_marj_atom W(win)); bilanco+dongu (v_finans dso/dio/dpo/ccc/twc/alacak/borc) + stok + net gecikmis DAIMA anlik; trend daima 12 ay. + 4 eksik metrik baglandi: olu stok (58,8M/1062), siparis bekleyen (siparis_miktar), olculen tahsilat (31g bi_tahsilat), fiyat sizintisi (15,8M maliyet-alti).',
 'Fatih: zaman secici her sekmede ama saygi gormuyordu (yalniz ust serit degisiyordu, 18+ kart kanon-sabit). "onlari donemle gormek isterlerse?" -> akis metrikleri pencerelenmeli (P&L dogru istek), bilanco/dongu anlik kalmali (bugunku pozisyon; snapshot tablolar gecmis tutmuyor; dongu 12-ay kanon). + placeholder kartlar (olu stok/siparis/olculen tahsilat/fiyat sizintisi) gercek verili -> baglandi. Tesvik-sonrasi marj veri-bloklu, acik kaldi.',
 '{"uc":["/api/bi/finans/oda?win"],"pencerelenen":["net_satis","smm","brut_kar","marj","marka","catal","kar","sizinti"],"anlik_kanon":["dso","dio","dpo","ccc","twc","alacak","borc","stok","net_gecikmis"],"trend":"daima 12 ay","eksik_baglanan":["olu_stok","siparis_bekleyen","olculen_tahsilat","fiyat_sizintisi"],"acik":"tesvik_sonrasi_marj (veri)","marker":"FINANS_WIN_V1","not":"server geriye-uyumlu; client ayagi ayri"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_WIN_V1');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='FINANS_WIN_V1';
