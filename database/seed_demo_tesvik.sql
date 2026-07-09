-- ============================================================
-- Derive Intelligence — Demo Teşvik Verileri 2026
-- Markalar: Continental, Goodyear/Dunlop, Michelin, Pirelli,
--           Kumho, Hankook, Yokohama, Petlas, Nexen, Falken
-- Her marka için: YAZ + KIŞ programı
-- Brisa (Bridgestone/Lassa) zaten yüklendi; burada sadece
-- Brisa kışlık programı ekleniyor.
-- ÖNEMLİ: Bu veriler DEMO/İLLÜSTRATİF oranları temsil eder.
--          Gerçek sözleşme oranlarıyla değiştirilmelidir.
-- Tenant: KRB (f8a5d20f-ecf8-4ce2-a492-69268fbb03fa)
-- Önce: migration_add_sezon.sql çalıştırılmış olmalı
-- ============================================================

-- Kısa makro: Brisa için sadece KIŞ (YAZ zaten mevcut)
-- Diğer markalar için hem YAZ hem KIŞ

-- ============================================================
-- BRISA — KIŞ Programı (YAZ'ı migration ile 'YAZ' olarak işaretlendi)
-- Ürünler: Blizzak (Bridgestone), Lassa Snoways
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- Bridgestone KIŞ PSR Perakende (Blizzak)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'BRİSA', 'Bridgestone', 2026, 'KIŞ', 'PSR', 'perakende',
  28.00, 4.00, 2.00, 3.00, 2.00, 10.00, 20.00,
  39.00, 75, 3.00, 30, 3.00, 'TRY',
  'DEMO – Blizzak serisi KIŞ programı. Sell-in Eylül-Kasım, erken sipariş avantajı yüksek.'),
-- Bridgestone KIŞ HRD Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'BRİSA', 'Bridgestone', 2026, 'KIŞ', 'HRD', 'perakende',
  27.00, 3.50, 1.50, 3.00, 1.50, 8.00, 18.00,
  36.50, 75, 3.00, 30, 3.00, 'TRY',
  'DEMO – Dueler H/L Alenza KIŞ. SUV segmenti.'),
-- Lassa KIŞ PSR Perakende (Snoways)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'BRİSA', 'Lassa', 2026, 'KIŞ', 'PSR', 'perakende',
  30.00, 4.50, 2.00, 4.00, 2.50, 8.00, 18.00,
  43.00, 75, 3.50, 30, 3.00, 'TRY',
  'DEMO – Snoways 4 KIŞ programı. Bütçe segment kış lideri.'),
-- Lassa KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'BRİSA', 'Lassa', 2026, 'KIŞ', 'PSR', 'toptan',
  29.00, 5.00, 0.00, 3.50, 2.00, 6.00, 15.00,
  39.50, 75, 3.50, 30, 3.00, 'TRY',
  'DEMO – Toptan KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- CONTINENTAL — YAZ + KIŞ (EUR Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'CONTINENTAL', 'Continental', 2026, 'YAZ', 'PSR', 'perakende',
  23.00, 2.00, 1.50, 2.00, 1.50, 10.00, 20.00,
  30.00, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – PremiumContact 7 / EcoContact 6 YAZ programı. EUR faturalı, kur riski.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'CONTINENTAL', 'Continental', 2026, 'YAZ', 'PSR', 'toptan',
  22.00, 2.50, 0.00, 1.50, 1.00, 10.00, 15.00,
  27.00, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – Toptan YAZ.'),
-- YAZ HRD Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'CONTINENTAL', 'Continental', 2026, 'YAZ', 'HRD', 'perakende',
  22.00, 1.50, 1.50, 2.00, 1.00, 8.00, 18.00,
  28.00, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – CrossContact YAZ. SUV/HRD.'),
-- KIŞ PSR Perakende (WinterContact TS 870)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'CONTINENTAL', 'Continental', 2026, 'KIŞ', 'PSR', 'perakende',
  24.00, 3.00, 2.00, 2.50, 2.00, 10.00, 22.00,
  33.50, 60, 2.00, 30, 1.80, 'EUR',
  'DEMO – WinterContact TS 870 KIŞ programı. Erken sipariş ek avantajı var.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'CONTINENTAL', 'Continental', 2026, 'KIŞ', 'PSR', 'toptan',
  23.00, 3.50, 0.00, 2.00, 1.50, 8.00, 18.00,
  30.00, 60, 2.00, 30, 1.80, 'EUR',
  'DEMO – Toptan KIŞ.'),
-- KIŞ HRD Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'CONTINENTAL', 'Continental', 2026, 'KIŞ', 'HRD', 'perakende',
  23.00, 2.50, 1.50, 2.50, 1.50, 8.00, 20.00,
  31.00, 60, 2.00, 30, 1.80, 'EUR',
  'DEMO – ContiCrossContact Winter KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- GOODYEAR / DUNLOP — YAZ + KIŞ (EUR Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- Goodyear YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Goodyear', 2026, 'YAZ', 'PSR', 'perakende',
  24.00, 2.00, 1.50, 2.00, 1.50, 10.00, 20.00,
  31.00, 60, 1.00, 30, 1.80, 'EUR',
  'DEMO – EfficientGrip Performance 2 YAZ. Dunlop dahil.'),
-- Goodyear YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Goodyear', 2026, 'YAZ', 'PSR', 'toptan',
  23.00, 2.50, 0.00, 1.50, 1.00, 8.00, 15.00,
  28.00, 60, 1.00, 30, 1.80, 'EUR',
  'DEMO – Toptan YAZ.'),
-- Goodyear YAZ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Goodyear', 2026, 'YAZ', 'HRD', 'perakende',
  23.00, 1.50, 1.50, 2.00, 1.00, 8.00, 18.00,
  29.00, 60, 1.00, 30, 1.80, 'EUR',
  'DEMO – Wrangler HP/AT YAZ.'),
-- Dunlop YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Dunlop', 2026, 'YAZ', 'PSR', 'perakende',
  22.00, 2.00, 1.00, 2.00, 1.00, 10.00, 20.00,
  28.00, 60, 1.00, 30, 1.80, 'EUR',
  'DEMO – Sport Maxx / SP FastResponse YAZ.'),
-- Goodyear KIŞ PSR Perakende (UltraGrip)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Goodyear', 2026, 'KIŞ', 'PSR', 'perakende',
  25.00, 3.00, 2.00, 2.50, 2.00, 10.00, 22.00,
  34.50, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – UltraGrip 9+ KIŞ programı.'),
-- Goodyear KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Goodyear', 2026, 'KIŞ', 'PSR', 'toptan',
  24.00, 3.50, 0.00, 2.00, 1.50, 8.00, 18.00,
  31.00, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – Toptan KIŞ.'),
-- Goodyear KIŞ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Goodyear', 2026, 'KIŞ', 'HRD', 'perakende',
  24.00, 2.50, 1.50, 2.50, 1.50, 8.00, 20.00,
  32.00, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – UltraGrip Ice Arctic SUV KIŞ.'),
-- Dunlop KIŞ PSR Perakende (Winter Sport)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'GOODYEAR', 'Dunlop', 2026, 'KIŞ', 'PSR', 'perakende',
  23.00, 2.50, 1.50, 2.00, 1.50, 8.00, 18.00,
  30.50, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – Winter Sport 5 KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- MİCHELİN — YAZ + KIŞ (EUR Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'MİCHELİN', 'Michelin', 2026, 'YAZ', 'PSR', 'perakende',
  21.00, 3.00, 1.00, 1.50, 0.00, 0.00, 0.00,
  26.50, 60, 2.00, 30, 2.00, 'EUR',
  'DEMO – Pilot Sport 5 / Primacy 4+ YAZ. Büyüme bonusu uygulanmaz; dönem primisi odak.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'MİCHELİN', 'Michelin', 2026, 'YAZ', 'PSR', 'toptan',
  20.00, 3.50, 0.00, 1.00, 0.00, 0.00, 0.00,
  24.50, 60, 2.00, 30, 2.00, 'EUR',
  'DEMO – Toptan YAZ.'),
-- YAZ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'MİCHELİN', 'Michelin', 2026, 'YAZ', 'HRD', 'perakende',
  20.00, 2.50, 1.00, 1.50, 0.00, 0.00, 0.00,
  25.00, 60, 2.00, 30, 2.00, 'EUR',
  'DEMO – Latitude Tour / Pilot Sport 4 SUV YAZ.'),
-- KIŞ PSR Perakende (Alpin 6 / Pilot Alpin)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'MİCHELİN', 'Michelin', 2026, 'KIŞ', 'PSR', 'perakende',
  22.00, 4.00, 1.50, 2.00, 0.00, 0.00, 0.00,
  29.50, 60, 2.50, 30, 2.00, 'EUR',
  'DEMO – Alpin 6 KIŞ programı. Dönem primisi kış sezonu yükseltilmiş.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'MİCHELİN', 'Michelin', 2026, 'KIŞ', 'PSR', 'toptan',
  21.00, 4.50, 0.00, 1.50, 0.00, 0.00, 0.00,
  27.00, 60, 2.50, 30, 2.00, 'EUR',
  'DEMO – Toptan KIŞ.'),
-- KIŞ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'MİCHELİN', 'Michelin', 2026, 'KIŞ', 'HRD', 'perakende',
  21.00, 3.50, 1.00, 2.00, 0.00, 0.00, 0.00,
  27.50, 60, 2.50, 30, 2.00, 'EUR',
  'DEMO – Latitude Alpin LA2 KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- PİRELLİ — YAZ + KIŞ (EUR Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PİRELLİ', 'Pirelli', 2026, 'YAZ', 'PSR', 'perakende',
  22.00, 2.50, 1.50, 2.00, 1.50, 12.00, 25.00,
  29.50, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – P7 Cinturato / P1 Verde YAZ. OE araç sonrası güçlü talep.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PİRELLİ', 'Pirelli', 2026, 'YAZ', 'PSR', 'toptan',
  21.00, 3.00, 0.00, 1.50, 1.00, 10.00, 20.00,
  26.50, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – Toptan YAZ.'),
-- YAZ HRD (P Zero Rosso / Scorpion Verde)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PİRELLİ', 'Pirelli', 2026, 'YAZ', 'HRD', 'perakende',
  21.00, 2.00, 1.00, 2.00, 1.50, 10.00, 20.00,
  27.50, 60, 1.50, 30, 1.80, 'EUR',
  'DEMO – Scorpion Verde / P Zero YAZ.'),
-- KIŞ PSR Perakende (Winter Sottozero 3)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PİRELLİ', 'Pirelli', 2026, 'KIŞ', 'PSR', 'perakende',
  23.00, 3.50, 2.00, 2.50, 2.00, 10.00, 22.00,
  33.00, 60, 2.00, 30, 1.80, 'EUR',
  'DEMO – Winter Sottozero 3 KIŞ programı.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PİRELLİ', 'Pirelli', 2026, 'KIŞ', 'PSR', 'toptan',
  22.00, 4.00, 0.00, 2.00, 1.50, 8.00, 18.00,
  29.50, 60, 2.00, 30, 1.80, 'EUR',
  'DEMO – Toptan KIŞ.'),
-- KIŞ HRD (Scorpion Winter)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PİRELLİ', 'Pirelli', 2026, 'KIŞ', 'HRD', 'perakende',
  22.00, 3.00, 1.50, 2.50, 1.50, 8.00, 20.00,
  30.50, 60, 2.00, 30, 1.80, 'EUR',
  'DEMO – Scorpion Winter 2 KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- KUMHO — YAZ + KIŞ (USD Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'KUMHO', 'Kumho', 2026, 'YAZ', 'PSR', 'perakende',
  28.00, 3.00, 2.00, 3.00, 2.00, 8.00, 18.00,
  38.00, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – Ecsta PS71 / Solus 4S YAZ. Agresif pazar payı stratejisi.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'KUMHO', 'Kumho', 2026, 'YAZ', 'PSR', 'toptan',
  27.00, 3.50, 0.00, 2.50, 1.50, 6.00, 15.00,
  34.50, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – Toptan YAZ.'),
-- YAZ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'KUMHO', 'Kumho', 2026, 'YAZ', 'HRD', 'perakende',
  27.00, 2.50, 1.50, 3.00, 2.00, 8.00, 18.00,
  36.00, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – Road Venture AT52 YAZ.'),
-- KIŞ PSR Perakende (Wintercraft)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'KUMHO', 'Kumho', 2026, 'KIŞ', 'PSR', 'perakende',
  29.00, 4.00, 2.00, 3.50, 2.50, 8.00, 20.00,
  41.00, 45, 2.50, 21, 2.50, 'USD',
  'DEMO – Wintercraft WP72 KIŞ programı.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'KUMHO', 'Kumho', 2026, 'KIŞ', 'PSR', 'toptan',
  28.00, 4.50, 0.00, 3.00, 2.00, 6.00, 15.00,
  37.50, 45, 2.50, 21, 2.50, 'USD',
  'DEMO – Toptan KIŞ.'),
-- KIŞ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'KUMHO', 'Kumho', 2026, 'KIŞ', 'HRD', 'perakende',
  28.00, 3.50, 1.50, 3.50, 2.00, 8.00, 18.00,
  38.50, 45, 2.50, 21, 2.50, 'USD',
  'DEMO – Road Venture KL71 KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- HANKOOK — YAZ + KIŞ (USD Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'HANKOOK', 'Hankook', 2026, 'YAZ', 'PSR', 'perakende',
  27.00, 2.50, 1.50, 2.50, 2.00, 10.00, 20.00,
  35.50, 45, 1.50, 21, 2.50, 'USD',
  'DEMO – Ventus S1 evo3 / Kinergy 4S2 YAZ. Hyundai/Kia OE tedarikçisi.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'HANKOOK', 'Hankook', 2026, 'YAZ', 'PSR', 'toptan',
  26.00, 3.00, 0.00, 2.00, 1.50, 8.00, 15.00,
  32.50, 45, 1.50, 21, 2.50, 'USD',
  'DEMO – Toptan YAZ.'),
-- YAZ HRD (Dynapro)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'HANKOOK', 'Hankook', 2026, 'YAZ', 'HRD', 'perakende',
  26.00, 2.00, 1.50, 2.50, 1.50, 8.00, 18.00,
  33.50, 45, 1.50, 21, 2.50, 'USD',
  'DEMO – Dynapro HP2 YAZ.'),
-- KIŞ PSR Perakende (Winter icept)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'HANKOOK', 'Hankook', 2026, 'KIŞ', 'PSR', 'perakende',
  28.00, 3.50, 2.00, 3.00, 2.00, 10.00, 22.00,
  38.50, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – Winter icept evo2 / RS3 KIŞ programı.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'HANKOOK', 'Hankook', 2026, 'KIŞ', 'PSR', 'toptan',
  27.00, 4.00, 0.00, 2.50, 1.50, 8.00, 18.00,
  35.00, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – Toptan KIŞ.'),
-- KIŞ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'HANKOOK', 'Hankook', 2026, 'KIŞ', 'HRD', 'perakende',
  27.00, 3.00, 1.50, 3.00, 1.50, 8.00, 18.00,
  36.00, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – Dynapro i*cept RW08 KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- YOKOHAMA — YAZ + KIŞ (USD Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'YOKOHAMA', 'Yokohama', 2026, 'YAZ', 'PSR', 'perakende',
  26.00, 2.00, 1.50, 2.00, 1.50, 10.00, 20.00,
  33.00, 45, 1.50, 21, 2.00, 'USD',
  'DEMO – BluEarth-GT AE51 / Advan Sport V105 YAZ.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'YOKOHAMA', 'Yokohama', 2026, 'YAZ', 'PSR', 'toptan',
  25.00, 2.50, 0.00, 1.50, 1.00, 8.00, 15.00,
  30.00, 45, 1.50, 21, 2.00, 'USD',
  'DEMO – Toptan YAZ.'),
-- KIŞ PSR Perakende (Geolandar / BluEarth Winter)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'YOKOHAMA', 'Yokohama', 2026, 'KIŞ', 'PSR', 'perakende',
  27.00, 3.00, 1.50, 2.50, 2.00, 8.00, 20.00,
  36.00, 45, 2.00, 21, 2.00, 'USD',
  'DEMO – BluEarth Winter V906 KIŞ programı.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'YOKOHAMA', 'Yokohama', 2026, 'KIŞ', 'PSR', 'toptan',
  26.00, 3.50, 0.00, 2.00, 1.50, 6.00, 15.00,
  33.00, 45, 2.00, 21, 2.00, 'USD',
  'DEMO – Toptan KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- PETLAS — YAZ + KIŞ (TRY Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PETLAS', 'Petlas', 2026, 'YAZ', 'PSR', 'perakende',
  22.00, 3.50, 1.00, 3.00, 2.00, 5.00, 15.00,
  31.50, 90, 2.00, 45, 3.00, 'TRY',
  'DEMO – Elegant PT311 / Velox Sport YAZ. Türk markası, TRY faturalı, kur riski sıfır.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PETLAS', 'Petlas', 2026, 'YAZ', 'PSR', 'toptan',
  21.00, 4.00, 0.00, 2.50, 1.50, 5.00, 12.00,
  29.00, 90, 2.00, 45, 3.00, 'TRY',
  'DEMO – Toptan YAZ.'),
-- YAZ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PETLAS', 'Petlas', 2026, 'YAZ', 'HRD', 'perakende',
  21.00, 3.00, 1.00, 3.00, 1.50, 5.00, 12.00,
  29.50, 90, 2.00, 45, 3.00, 'TRY',
  'DEMO – Imperium PT515 HRD YAZ.'),
-- YAZ TBR (Kamyon-Otobüs)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PETLAS', 'Petlas', 2026, 'YAZ', 'TBR', 'perakende',
  18.00, 4.00, 0.00, 3.00, 2.00, 5.00, 10.00,
  27.00, 90, 1.50, 45, 3.00, 'TRY',
  'DEMO – TBR (ağır ticari). Bütçe segment lider.'),
-- KIŞ PSR Perakende (Full Grip / Ice Power)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PETLAS', 'Petlas', 2026, 'KIŞ', 'PSR', 'perakende',
  23.00, 5.00, 1.50, 4.00, 2.50, 5.00, 15.00,
  36.00, 90, 2.50, 45, 3.00, 'TRY',
  'DEMO – Full Grip PT935 KIŞ programı. Bütçe segment kış hakimi. Dönem primisi en yüksek kalem.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PETLAS', 'Petlas', 2026, 'KIŞ', 'PSR', 'toptan',
  22.00, 5.50, 0.00, 3.50, 2.00, 5.00, 12.00,
  33.00, 90, 2.50, 45, 3.00, 'TRY',
  'DEMO – Toptan KIŞ.'),
-- KIŞ HRD
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'PETLAS', 'Petlas', 2026, 'KIŞ', 'HRD', 'perakende',
  22.00, 4.00, 1.00, 3.50, 2.00, 5.00, 12.00,
  32.50, 90, 2.50, 45, 3.00, 'TRY',
  'DEMO – Imperium KIŞ / Ice Power HRD.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- NEXEN — YAZ + KIŞ (USD Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'NEXEN', 'Nexen', 2026, 'YAZ', 'PSR', 'perakende',
  30.00, 2.50, 2.00, 3.00, 2.50, 8.00, 20.00,
  40.00, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – N Fera SU1 / N Blue 4Season YAZ. Agresif büyüme programı.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'NEXEN', 'Nexen', 2026, 'YAZ', 'PSR', 'toptan',
  29.00, 3.00, 0.00, 2.50, 2.00, 6.00, 15.00,
  36.50, 45, 2.00, 21, 2.50, 'USD',
  'DEMO – Toptan YAZ.'),
-- KIŞ PSR Perakende (Winguard)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'NEXEN', 'Nexen', 2026, 'KIŞ', 'PSR', 'perakende',
  31.00, 3.50, 2.00, 3.50, 3.00, 8.00, 22.00,
  43.00, 45, 2.50, 21, 2.50, 'USD',
  'DEMO – Winguard Sport 2 KIŞ programı.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'NEXEN', 'Nexen', 2026, 'KIŞ', 'PSR', 'toptan',
  30.00, 4.00, 0.00, 3.00, 2.50, 6.00, 18.00,
  39.50, 45, 2.50, 21, 2.50, 'USD',
  'DEMO – Toptan KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- FALKEN (Sumitomo) — YAZ + KIŞ (EUR Faturalı)
-- ============================================================

INSERT INTO bi_tedarikci_tesvik (
  tenant_id, tedarikci_adi, marka, yil, sezon, segment, kanal,
  fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
  kesin_siparis_pct, buyume_bonus_pct,
  buyume_hedef_min_pct, buyume_hedef_ust_pct,
  max_toplam_pct, odeme_vadesi_gun,
  erken_odeme_iskonto_pct, erken_odeme_gun,
  gecikme_faizi_aylik_pct, fatura_kuru,
  notlar
) VALUES
-- YAZ PSR Perakende
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'SUMİTOMO', 'Falken', 2026, 'YAZ', 'PSR', 'perakende',
  25.00, 2.00, 1.50, 2.00, 1.50, 8.00, 18.00,
  32.00, 60, 1.50, 30, 2.00, 'EUR',
  'DEMO – Ziex ZE914 EcoRun YAZ. Sumitomo/Falken. EUR faturalı.'),
-- YAZ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'SUMİTOMO', 'Falken', 2026, 'YAZ', 'PSR', 'toptan',
  24.00, 2.50, 0.00, 1.50, 1.00, 6.00, 12.00,
  29.00, 60, 1.50, 30, 2.00, 'EUR',
  'DEMO – Toptan YAZ.'),
-- KIŞ PSR Perakende (Eurowinter)
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'SUMİTOMO', 'Falken', 2026, 'KIŞ', 'PSR', 'perakende',
  26.00, 3.00, 1.50, 2.50, 2.00, 8.00, 20.00,
  35.00, 60, 2.00, 30, 2.00, 'EUR',
  'DEMO – Eurowinter HS01 KIŞ programı.'),
-- KIŞ PSR Toptan
('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa', 'SUMİTOMO', 'Falken', 2026, 'KIŞ', 'PSR', 'toptan',
  25.00, 3.50, 0.00, 2.00, 1.50, 6.00, 15.00,
  32.00, 60, 2.00, 30, 2.00, 'EUR',
  'DEMO – Toptan KIŞ.')
ON CONFLICT (tenant_id, marka, yil, segment, kanal, sezon) DO UPDATE SET
  fatura_alti_pct = EXCLUDED.fatura_alti_pct,
  donem_primi_pct = EXCLUDED.donem_primi_pct,
  sellout_primi_pct = EXCLUDED.sellout_primi_pct,
  kesin_siparis_pct = EXCLUDED.kesin_siparis_pct,
  buyume_bonus_pct = EXCLUDED.buyume_bonus_pct,
  max_toplam_pct = EXCLUDED.max_toplam_pct,
  odeme_vadesi_gun = EXCLUDED.odeme_vadesi_gun,
  erken_odeme_iskonto_pct = EXCLUDED.erken_odeme_iskonto_pct,
  erken_odeme_gun = EXCLUDED.erken_odeme_gun,
  gecikme_faizi_aylik_pct = EXCLUDED.gecikme_faizi_aylik_pct,
  fatura_kuru = EXCLUDED.fatura_kuru,
  notlar = EXCLUDED.notlar;

-- ============================================================
-- Sonuç özeti
-- ============================================================
SELECT
  marka,
  tedarikci_adi,
  sezon,
  fatura_kuru,
  COUNT(*) AS kayit_sayisi,
  ROUND(AVG(max_toplam_pct), 1) AS ort_max_tesvik,
  MIN(odeme_vadesi_gun) AS min_vade_gun,
  MAX(odeme_vadesi_gun) AS maks_vade_gun
FROM bi_tedarikci_tesvik
WHERE yil = 2026
GROUP BY marka, tedarikci_adi, sezon, fatura_kuru
ORDER BY marka, sezon;
