-- ============================================================================
-- bi_insa_gunlugu — TAHSILAT_V1: yeni bi_tahsilat tablosu (7. ERP dosyasi, olculen odeme davranisi)
-- Kural 4 ayak izi. ⚠ YALNIZCA yukleme CANLIYA gectikten SONRA calistir. Sunucuda:
--   set -a; . ./.env; set +a
--   docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" krb-assessment-postgres \
--     psql -U assessment_app -d assessment_platform -f - < insa_gunlugu_tahsilat.sql
-- ============================================================================
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT v.adim, v.ne, v.neden, jsonb_build_object('aciklama', v.detay), now()
FROM (VALUES
  ('TAHSILAT_V1',
   'Yeni bi_tahsilat tablosu: Tahsilat Durumu Raporu_V2 (7. ERP dosyasi) -> OLCULEN odeme davranisi ve gercek DSO. Fatura<->tahsilat eslesmesi, tam gecmis 2021->bugun.',
   'Musteri skorunda Odeme bileseni (~%35) simdiye kadar alacak-yaslandirma overdue-orani VEKILIYLE suruluyordu; olculen odeme zamanlamasiyla korelasyonu ~%2 (gurultu). bi_tahsilat gercek tahsilat suresi + %gec ile bunu OLCULEN veriyle degistirmenin kaynagi olur.',
   'Motor: erp_ingest.py yeni tip tahsilat (imza Ödenen Tutar+Tahsilat Süresi+Tahsilat türü+Fatura Vade Tarihi) + _tahsilat_grupla (fatura satiri->cari; tutar-agirlikli sure/gecikme; Tahsilat Süresi/Vadesi Geçen Gün bos ise tarihlerden turetir -> ayni-gun Sanal Pos kayitlari DUSMEZ). Iki pencere: tam gecmis + son 12 ay (skor guncel davranisi tercih etsin). Alanlar: ort_tahsilat_suresi, ort_gecikme_gun, gec_odeme_orani, son12_*; musteri_mi=grup TEDARIKCI/PERSONEL degil. Dogrulama (yuklenen dosya customercollection 2021-2026 07.12, 24 Tem): 38.382 cari, 5.012.766.052 TL tahsilat, tutar-agirlikli 30,2 gun, deger bazinda %52,3 gec. son12 aktif 11.450 cari. (Ilk validasyon dosyasi 1Tahsilat_V2 ile ~%1 fark = ayni sorgunun farkli zamanli cekimi, yapi ayni.) Kapilar gecti, mukerrer 0. YALNIZ bi_tahsilat yazildi; mevcut tablolar/skor ETKILENMEDI (skor baglama AYRI adim). Detay: claude/derive-tahsilat-durumu-phase.md.')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim);

SELECT adim, LEFT(ne, 60) AS ne, ts::date FROM bi_insa_gunlugu WHERE adim = 'TAHSILAT_V1';
