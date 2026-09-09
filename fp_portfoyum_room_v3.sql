-- FINGERPRINT — PORTFOYUM_ROOM_V3 (hero rep-metrikleri)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_ROOM_V3',
       'Portföyüm hero: rep-seviyesi ciro-ağırlıklı ödeme metrikleri — ağırlıklı satış vadesi + ağırlıklı tahsilat süresi (vade+gecikme) + düzenli ödeme oranı (100 - ağırlıklı geç%)',
       'Rep kendi portföyünün ödeme sağlığını tek bakışta görsün (Fatih isteği)',
       '{"dosya":"shells/saha.js","view":"vPortfoyum","fn":"_pfRepMetrics","kaynak":"client (agirlikli_vade/son12_gecikme/son12_gec_orani/ciro_12 ile ağırlıklı)","endpoint_degisimi":"YOK","marker":"PORTFOYUM_ROOM_V3"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_ROOM_V3');
SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_ROOM_V3';
