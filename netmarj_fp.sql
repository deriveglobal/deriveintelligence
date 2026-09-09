INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_TESVIK_NETMARJ_V1',
 'Finans oda Karlilik "Net Marj (tesvik sonrasi)" karti bloklu->CANLI. Gerceklesen net marj = brut_marj_pct + kazanilan_tesvik/ciro (yalniz markalardan, chip g2Tesvik ile tutarli). Saf CLIENT hesap (FIN.brut_marj_pct + oda.tesvik.tutar/FIN.net_satis_lastik*100), server sorgusu YOK. ?win seciciye uyar (DONEM dongusune eklendi). 12ay ~%15,6.',
 'Fatih "?? / hesaplayabilir miyiz?": kart orijinalde per-SKU kesin_net_marj_pct (bi_tedarikci_tesvik tier, seyrek/6 marka bloklu) bekliyordu. Karar (Fatih onayi "gerceklesen·markalardan"): tier verisini beklemeden, fiilen hakedilen tesvik uzerinden yukaridan-asagi gerceklesen net marj. Kod formulu ana oda 25460 ile ayni: (ciro-smm+prim)/ciro. Tahmin degil, gerceklesen. tier-bazli kesin_net ayri gelecek rafinasyon.',
 '{"kart":"g2NetMarj","gorunum":"karlilik","formul":"brut_marj_pct + tesvik/net_satis_lastik*100","tesvik_tabani":"markalardan (tedarikci-only)","hesap":"client-side, server yok","12ay_pct":15.6,"marker":"FINANS_TESVIK_NETMARJ_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_TESVIK_NETMARJ_V1');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='FINANS_TESVIK_NETMARJ_V1';
