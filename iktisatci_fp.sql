-- IKTISATCI_BAKIS_V1 — GLOBAL kayit (tenant_id YOK; yapi/recete/kural, KRB sayisi yok).
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'IKTISATCI_BAKIS',
 'CEO Asistani sistem haritasina "IKTISATCI BAKIS" bolumu eklendi: ekonomist AYRI yuzey degil, CEO asistaninin bir yetenegi. Bes aci recetesi (vade makasi, fiyat gecisgenligi, on-siparis kaderi, marka sagligi/asiri-baglama, nakit-marj rejimi) + yorum kurali. Asistan bunlari ham execute_query ile canli hesaplar; kanonik sayi kanon katmandan.',
 'Fatih: "bu ekonomist CEO asistanindan farkli olmamali, tek super-guclu asistan olmali." + "Claude bizim tasarladigimiz motorlarla sinirli kalmamali" -> asistanda zaten ham SQL var (motor tavan degil); eksik olan ekonomist BILGISI idi. Ayri /oruntu endpoint + ayri Iktisatci paneli TASARIMI iptal; birlesik: sistem-haritasi + defter, tipki IKI_IS/DSO gibi.',
 '{"marker":"IKTISATCI_BAKIS_V1","aci":["vade_makasi","fiyat_gecisgenligi","onsiparis_kaderi","marka_sagligi","nakit_marj_rejimi"],"mimari":"CEO asistani = ekonomist; ham SQL kesif + kanon katman sabit sayi; ayri endpoint iptal","dogrulandi":"vade makasi (satis 43g vs alim 50g, +7.6->-6.6 kayma), gecisgenlik (Continental/Herkul sikisma), on-siparis kaderi (buyume-ayarli %63 fazla), sizinti-olu ortusmesi (Lassa/Bridgestone/Continental)","sonraki":"curated fonksiyonlar (onsiparis_kaderi/vade_makasi/marka_saglik) guvenilirlik icin"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='IKTISATCI_BAKIS');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='IKTISATCI_BAKIS';
