INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_SIPARIS_REVERT_V1',
 'Finans oda "Siparis bekleyen" karti "—"e geri cekildi (rozet: dogrulaniyor). bi_stok_durumu.siparis_miktar kolonu erp_ingest.py mapping''inde YOK; ERP anlami + populasyon kaynagi izlenemedi. Diger 3 metrik (olu stok/olculen tahsilat/sizinti) dogrulanmis, kaldi.',
 'Fatih: "hangi tablo? sipariş tablosu hatirlamiyorum." Dogru: ayri tablo yok, bi_stok_durumu kolonu; ama erp_ingest.py''de siparis_miktar mapping yok (bekleyen_siparis=bi_musteri_risk, bi_on_siparis=ayri sezon tablosu, farkli). Anlami kanitlanamayan kolonu finans kartinda gostermek yanlis -> boş birak. Gercek pending-order metrigi istenirse bi_on_siparis (sezon on-siparis) ya da bi_musteri_risk.bekleyen_siparis ayri tasarlanir.',
 '{"kart":"siparis_bekleyen","aksiyon":"placeholder geri","neden":"siparis_miktar ERP anlami+kaynak dogrulanamadi (erp_ingest mapping yok)","alternatif_kaynak":["bi_on_siparis","bi_musteri_risk.bekleyen_siparis"],"marker":"FINANS_SIPARIS_REVERT_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_SIPARIS_REVERT_V1');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='FINANS_SIPARIS_REVERT_V1';
