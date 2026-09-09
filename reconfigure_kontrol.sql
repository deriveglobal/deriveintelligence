-- Eşleştirmeyi rep-onayına çevir: tahmin ettiğimiz eşleşmeler KONTROL kuyruğuna (musteri_kodu SIFIRLANIR),
-- aday bulunmayanlar (NONE) zaten YENİ müşteri = SAHA_ZIYARETI kalır. Öneriler silinir (rep kendi eşleştirir).
-- Bugün import edilen 4 rep müşterisini hedefler. Ziyaret/müşteri KORUNUR.
BEGIN;
-- 1) auto-uygulanmış (musteri_kodu dolu) → incele + linki sıfırla
UPDATE saha_musteri SET kayit_kaynagi='EXCEL_IMPORT_KONTROL', musteri_kodu=NULL, updated_at=now()
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND created_at::date=current_date AND musteri_kodu IS NOT NULL;
-- 2) öneri (BEKLIYOR) olanlar → incele
UPDATE saha_musteri SET kayit_kaynagi='EXCEL_IMPORT_KONTROL', updated_at=now()
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND created_at::date=current_date
   AND id IN (SELECT saha_musteri_id FROM saha_eslestirme_oneri
              WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND durum='BEKLIYOR');
-- 3) tüm önerilerimi sil (rep ERP'den kendi arayıp eşleştirecek)
DELETE FROM saha_eslestirme_oneri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND saha_musteri_id IN (SELECT id FROM saha_musteri
                           WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND created_at::date=current_date);
COMMIT;
-- Sonrası: her rep "Müşteriler" ekranında "🔎 Kontrol Bekleyen Müşteri" panelinde kendi kayıtlarını görür,
--   🏢 ERP'den eşleştir / ✓ Yeni müşteri ile karar verir; karar verilince uyarı kaybolur.
