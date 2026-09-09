-- FINGERPRINT — NET_GECIKMIS_KANON_V1 (net gecikmiş kanonu canlı)
-- Calistir:  cat fp_net_gecikmis.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'NET_GECIKMIS_KANON_V1',
 'Net gecikmis KANONU: yeni view v_net_gecikmis_musteri (son export snapshot, musteri basina toplanmis, musteri_mi & TEDAR-disi, tedarikci mahsubu LEAST(tedarikci_bakiye,0), musteri bazinda 0-floor). net 53,4M / brut 86,3M / 578 gecikmis musteri. v_finans_ticari_sermaye.net_gecikmis buna baglandi (eski 55,3 hamdi: +tedarikci_bakiye pozitifi de topluyordu = yanlis). Bu view''i okuyan uclar otomatik duzeldi.',
 'Net gecikmis kodda ~15+ ayri yerde farkli hesaplaniyordu (brut/net, DISTINCT ON/MAX, TEDAR-disi var/yok, mahsup var/yok/ham) -> 3 farkli deger (view 55,3 / kokpit 54,9 / risk 53,4). Fatih: her metrik tek tanim/tek kaynak. Kanon = 53,4M; brut isteyen risk raporlari brut_gecikmis kolonuna baglanir.',
 '{"marker":"NET_GECIKMIS_KANON_V1","kaynak":"v_net_gecikmis_musteri","tanim":"son export · musteri basina · musteri_mi & TEDAR-disi · LEAST mahsup · 0-floor","deger":{"net_M":53.4,"brut_M":86.3,"gecikmis_musteri":578},"konsantrasyon":"YEDI OTO 21,9M = %41","bagli":["v_finans_ticari_sermaye.net_gecikmis"],"acik":["oda karti/kokpit/harita call-site view''a cekilecek","risk MAX-raporlari brut_gecikmis''e","v_finans alt-CTE ar/ap/stok tenant filtresiz (SaaS)"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='NET_GECIKMIS_KANON_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'v_net_gecikmis_musteri','view','Net/brut gecikmis alacak — TEK kanonik kaynak (musteri-kirilimli). Tum ekranlar buradan okur.','son export · musteri basina toplanmis · musteri_mi & TEDAR-disi · LEAST(tedarikci_bakiye,0) mahsup · 0-floor. Kolonlar: brut_gecikmis, tedarikci_mahsup, net_gecikmis.','finans','canli','kanitli','{"marker":"NET_GECIKMIS_KANON_V1","net_M":53.4}'::jsonb,true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='v_net_gecikmis_musteri');

SELECT adim FROM bi_insa_gunlugu WHERE adim='NET_GECIKMIS_KANON_V1';
SELECT ad,durum FROM bi_yetenek WHERE ad='v_net_gecikmis_musteri';
