-- DONGU_KANON_ANA_V1 fingerprint. Deploy (host patch + build + konteyner marker=2) DOGRULANDIKTAN SONRA calistir.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'DONGU_KANON_ANA_V1',
 '/api/bi/ana "Bugun" odasi dso_gun + stok_gun -> v_finans_ticari_sermaye (bilanco-tabanli kanon; DSO 100 / DIO 146). Eski ciro-bazli proxy (risk/gunluk-ciro, s.deger/gunluk-ciro) kaldirildi. Bugun odasi dongu sayilari artik Finans odasi ile birebir.',
 'Fatih: okuyan yuzeyleri tek kaynaga bagla (Dongu Faz B). Bugun ve Finans ayri DSO gosteriyordu (~109 vs 100). Kanon = v_finans_ticari_sermaye (FINANS_DONGU_MULTITENANT_V1). Olculen tahsilat hizi (bi_metrik_gecmis ''dso'', ~27) AYRI "Tahsilat Hizi" lensi olarak KORUNDU (Fatih onerisi 1) — feeder''a dokunulmadi.',
 '{"uc":["/api/bi/ana (Bugun/sermaye)"],"alan":["dso_gun","stok_gun"],"kaynak":"v_finans_ticari_sermaye","kanon":"bilanco-tabanli CCC","marker":"DONGU_KANON_ANA_V1","ayri_lens_korundu":["bi_metrik_gecmis dso = tahsilat hizi","pricing/ccc = olculen","dso-icgoru = sinif drill-down","cash-cycle/financial-perspective = vade proxy"],"faz":"B","karar":"Fatih oneri 1: olculen lens ayri+etiketli kalir"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='DONGU_KANON_ANA_V1');

SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='DONGU_KANON_ANA_V1';
