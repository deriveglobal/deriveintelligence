-- Birlesik medyani TUM hucrelere yay (yalniz taban modellerden; turetilmis modeller katilmaz)
INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                       ufuk_gun,yontem,model_ad,tahmin_deger,kosum,varsayimlar)
SELECT t.tenant_id, min(t.uretim_gun), t.nesne, t.varlik_tipi, t.varlik_kodu, t.hedef_donem,
       t.ufuk_gun,'taban','birlesik_medyan',
       percentile_cont(0.5) WITHIN GROUP (ORDER BY t.tahmin_deger),'backtest',
       jsonb_build_object('aday_say',count(*))
  FROM bi_tahmin t
  JOIN bi_tahmin_model m ON m.model_ad=t.model_ad
 WHERE t.kosum='backtest' AND t.tahmin_deger>0
   AND m.aile IN ('naif','duzlestirme','naif+trend','yapisal')
 GROUP BY t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.hedef_donem,t.ufuk_gun
HAVING count(*) >= 4
ON CONFLICT DO NOTHING;

-- Turetilmis parametreler
INSERT INTO bi_parametre (ad,deger,tur,turetim_fn,gozlem_say,kanit,gerekce) VALUES
 ('sampiyon_marj', 0.54, 'turetilmis','olcum:2.83*SE/ort_mape', 315,
  '{"medyan_marj":0.542,"p75":0.751,"ort_pencere":6.8,"yari_yariya_uyum_pct":47.1}',
  'Pencere-ortalamasi MAPE nin standart hatasindan: farkin anlamli sayilmasi icin 2.83*SE gerekir. Onceki deger 0.10 idi = gurultuyle sampiyon degistiriyorduk.'),
 ('cekirdek_max_lag', 11, 'turetilmis','olcum:kumulatif>=99%', 48,
  '{"lag10_kumulatif":98.87,"lag11_kumulatif":99.60,"lag11_marjinal":0.74}',
  'Kumulatif agirligin %99 u ilk astigi gecikme; sonrasi marjinal katki %1 in altinda.'),
 ('sampiyon_birlesim_onceligi', 1, 'politika', NULL, NULL,
  '{"yari_yariya_uyum_pct":47.1}',
  'Siralama belirlenebilir degilse (yari-yariya uyum %47) secmek yerine birlestirilir. Tek model, birlesimi olculen marjla yenemiyorsa birlesim kalir.')
ON CONFLICT DO NOTHING;
