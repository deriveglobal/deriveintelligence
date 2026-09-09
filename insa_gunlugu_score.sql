-- bi_insa_gunlugu — Faz 2b: müşteri skoru "Ödeme" + KRB kıyas ölçülen ödeme davranışına bağlandı.
-- ⚠ YALNIZCA her iki yama (SCORE_ODEME_V1 + TAHSILAT_KIYAS_V1) CANLIYA gectikten SONRA calistir.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT v.adim, v.ne, v.neden, jsonb_build_object('aciklama', v.detay), now()
FROM (VALUES
  ('SCORE_ODEME_V1',
   'Müşteri skoru "Ödeme" bileşeni (s_pay, ağırlık %35) overdue-proxy yerine ÖLÇÜLEN ödeme davranışına (bi_tahsilat) bağlandı.',
   'Eski s_pay = 0,6·(fatura vade süresi) + 0,4·(overdue/bakiye); ölçülen ödeme zamanlamasıyla korelasyon ~%2 (gürültü). Yeni s_pay = 0,6·(1−%geç) + 0,4·(1−ort_gecikme_gün/60), son12 aktifse son12 penceresi yoksa tam geçmiş; tahsilat kaydı yoksa eski proxy fallback.',
   'Motor: server_container.mjs 3 skor sorgusu (musteri-fiyat, musteri-skor, musteri-fiyat-liste) — her birine tah CTE (bi_tahsilat) + base''e eff_gec/eff_gun/has_tah + s_pay CASE. FIYAT DEĞİŞMEDİ (fiyat s_vol+s_risk kullanır; s_pay yalnız skor + vade önerisini etkiler). Before/after (5637 cari, 5495 tahsilatlı): avg skor 66,3→64,9, 1025 düştü / 1448 yükseldi, ort mutlak değişim 3,7, |Δ|≥15 olan 556 cari (proxy''nin en yanıldıkları). node --check geçti, konteyner temiz açıldı.')
, ('TAHSILAT_KIYAS_V1',
   'KRB kıyas: "Tahsilat" metriği GERÇEK DSO''ya (ölçülen tahsilat süresi), "Gecikme" metriği ölçülen ödeme davranışına (%geç + ort gün) çevrildi.',
   'Eski "Tahsilat" = fatura vade süresi (sözleşme), "Gecikme" = overdue/ciro (anlık snapshot). Gerçek tahsilat davranışını göstermiyordu. Yeni: bi_tahsilat''tan cari DSO vs KRB ort. DSO, ölçülen %geç + ort gecikme gün vs KRB ort.',
   'Motor: musteri-kiyas + iyilestirme-hedefleri sorgularına tah+kt CTE + kolonlar; musteri-kiyas kartında Tahsilat→DSO, Gecikme→ölçülen JS. Tahsilat kaydı yoksa eski gösterim fallback. iyileştirme bayrakları şimdilik eski mantıkta. node --check geçti.')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim);

SELECT adim, LEFT(ne,55) ne, ts::date FROM bi_insa_gunlugu WHERE adim IN ('SCORE_ODEME_V1','TAHSILAT_KIYAS_V1');
