-- ============================================================================
-- bi_insa_gunlugu — ALACAK_YASLANDIRMA_V1: cari risk kaynağı CARİ RİSK -> Belge Bazlı Alacak Yaşlandırma
-- Kural 4 ayak izi. ⚠ YALNIZCA cutover (Faz 1) CANLIYA geçtikten SONRA çalıştır (yoksa CEO asistan
--   var olmayan bir değişikliği duyurur). Sunucuda:
--   set -a; . ./.env; set +a; export PW="$POSTGRES_PASSWORD"
--   docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
--     psql -U assessment_app -d assessment_platform -f - < insa_gunlugu_alacak_yaslandirma.sql
-- ============================================================================

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT v.adim, v.ne, v.neden, jsonb_build_object('aciklama', v.detay), now()
FROM (VALUES
  ('ALACAK_YASLANDIRMA_V1',
   'Cari risk kaynağı değişti: CARİ RİSK RAPORU yerine BELGE BAZLI ALACAK YAŞLANDIRMA (SAP açık A/R faturaları + kredi limiti). bi_musteri_risk artık buradan beslenir.',
   'Eski CARİ RİSK "Vadesi Geçmiş Bakiye" alanı Ödeme Biçimi''ne göre kümülatif çoğalıyordu ve GERÇEK gecikmiş DEĞİLDİ (ROTA raporda 19,9M, gerçekte 1,5M). Yeni rapor müşteri-seviyesi net bakiyeyi (OCRD.Balance) KESİN veriyor; gecikmiş açık faturaların vade yaşından TÜRETİLİR.',
   'Motor: erp_ingest.py yeni tip alacak_yaslandirma (İngilizce başlık, imza Customer/Vendor Code+Açık Tutar+Vadesi Geçen Gün+Document Total) + grupla hook (belge->cari toplama) + gun tipi (Vadesi Geçen Gün, 1900/1904 tarih bozulmasına dayanıklı). Eşleme: hesap_bakiyesi=Account Balance (kesin), kredi_limiti=OCRD.CreditLine, grup=Group Name. toplam_risk=max(bakiye,0) (çek/senet kaynağı yok; eski dosyada da ~%0 doluydu, Toplam Risk≈Hesap Bakiyesi). vadesi_gecmis=FIFO TÜRETİM: en eski fatura önce ödenir varsayımı (TBK vade/eski borç önceliği) → kalan net bakiye içindeki gün>0 kısmı; balance-forward şişmeyi (açık>>bakiye) net bakiyeyle sınırlar. Güven: bakiye=kesin, vadesi_gecmis=türetilmiş/yaklaşık. musteri_mi=grup TEDARİKÇİ/PERSONEL değil (e-ticaret EM kodları dahil; eski startswith(M) değil). Doğrulama (24 Tem, tam dosya): 6537 belge->1383 cari, alacak 233,9M, gecikmiş(FIFO) 92,2M (eski cap 53,2M EKSİK sayıyordu), ROTA bakiye 1.509.181 vadesi 0, limit aşımı canlı (MUTAFLAR 44M/1M limit). Kapılar geçti, mükerrer 0, mevcut 8 tip etkilenmedi. ⚠ MERGE_KORU_V1: yükleme carileri-koru (carry-forward) — dosyada OLMAYAN ~37,4k cari KİMLİĞİYLE (grup/kanal) korunur, riski 0; HİÇBİR müşteri düşmez (38.765→38.801, dropout 0, taşınan grup-dolu 37.844). Canlı cutover (24 Tem): alacak 233,7M (ham bakiye; dosya floored 233,9M), gecikmiş 92.220.555, ROTA 1.509.181/0. ⚠ Eski CARİ RİSK MANUEL yüklemesi DURDURULDU; oto entegrasyon başlayınca CARİ RİSK feed setine ALINMAYACAK, yerini Belge Bazlı Alacak Yaşlandırma alır. Detay: claude/derive-alacak-yaslandirma-dryrun.md. QA/geri-alma: QA_alacak_yaslandirma_runbook.md.')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim);

SELECT adim, LEFT(ne, 60) AS ne, ts::date FROM bi_insa_gunlugu WHERE adim = 'ALACAK_YASLANDIRMA_V1';
