-- Onboarding import doğrulama (çalıştırdıktan SONRA)
\pset pager off
\echo '== rep başına EXCEL_MIGRASYON ziyaret =='
SELECT rep_id, rep_adi, count(*) ziyaret, min(ziyaret_tarihi) ilk, max(ziyaret_tarihi) son
 FROM saha_ziyaret WHERE kaynak='EXCEL_MIGRASYON'
   AND rep_id IN ('ab23df67-75c8-40ff-bac9-2de66c6a76b6','79d8adeb-c58f-4564-b625-a023e141e14b','0c5e2e6e-64a8-4c9b-9c45-81060ce6b042')
 GROUP BY rep_id, rep_adi ORDER BY ziyaret DESC;
\echo '== yeni müşteri (bugün, SAHA_ZIYARETI) + ERP bağlı mı =='
SELECT count(*) toplam,
       count(*) FILTER (WHERE musteri_kodu IS NOT NULL) erp_bagli,
       count(*) FILTER (WHERE musteri_kodu IS NULL) erp_bagsiz
 FROM saha_musteri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND created_at::date=current_date;
\echo '== bekleyen eşleşme önerisi =='
SELECT count(*) FROM saha_eslestirme_oneri WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND durum='BEKLIYOR';
