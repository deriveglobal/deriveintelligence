-- NET_GECIKMIS_FINANS_V1 fingerprint. Konteyner marker=2 sonrasi.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'NET_GECIKMIS_FINANS_V1',
 'legacy /api/bi/finans (deger agaci) gecikmis + gecikmis_musteri brut -> net (v_net_gecikmis_musteri). Son canli gross net-gecikmis yuzeyi kapandi; net_sermaye a.bakiye kullaniyor (gecikmis display-only) -> guvenli.',
 'Net gecikmis kanon programinin kalan yuzeyi. /api/bi/finans bi.js:904 tarafindan hala cagriliyor (olu degil), gross ~86,3M gosteriyordu -> net 53,4M. Diger kalan yuzeyler zaten net: harita il/cari inline-mahsup, _dsoSql/_topSql inline-net, pricing/ccc AYRI olculen lens.',
 '{"uc":["/api/bi/finans"],"alan":["gecikmis","gecikmis_musteri"],"kaynak":"v_net_gecikmis_musteri","marker":"NET_GECIKMIS_FINANS_V1","not":"net gecikmis TUM canli yuzeyler artik NET"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='NET_GECIKMIS_FINANS_V1');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='NET_GECIKMIS_FINANS_V1';
