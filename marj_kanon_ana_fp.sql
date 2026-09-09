-- MARJ_KANON_ANA_V1 fingerprint. Konteyner marker=2 DOGRULANDIKTAN SONRA calistir.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MARJ_KANON_ANA_V1',
 '/api/bi/ana "Bugun" odasi marj''i ERP-cikis_tutari paralel motorundan KANONA baglandi: ciro=bi_satis LASTIK% (retread DAHIL), marj%=bi_marj_atom akis maliyeti (Finans/Kokpit ile ayni). Anlati stringleri de duzeltildi (kaynak/sinir/kapsam/mutabakat). marj_pct 14,8 -> 11,5.',
 'Kanon programinin son sistemik marj ayrismasi. Teshis: Bugun %14,8 (SMM=bi_stok_hareket.cikis_tutari, evren TIC+TUK retread-haric) vs kanon %11,5 (atom akis, LASTIK% retread-dahil). Iki kaynak: (a) retread dusurup susleme (EK23 ile ayni), (b) ERP-maliyeti ikinci kanon. Fatih ilkesi: rakam neyse o, is kolu dusurup susleme yok -> durust %11,5.',
 '{"uc":["/api/bi/ana (Bugun/marj)"],"onceki":{"smm":"bi_stok_hareket.cikis_tutari","evren":"TIC+TUK retread-haric","marj":14.8},"yeni":{"ciro":"bi_satis LASTIK%","marj":"bi_marj_atom akis","deger":11.5},"marker":"MARJ_KANON_ANA_V1","not":"paralel maliyet motoru kaldirildi; ERP mutabakat -> maliyet kapsam%"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MARJ_KANON_ANA_V1');

SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='MARJ_KANON_ANA_V1';
