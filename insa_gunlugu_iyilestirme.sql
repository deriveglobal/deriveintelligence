-- bi_insa_gunlugu — İyileştirme Hedefleri bayrakları ölçülen ödeme sinyaline bağlandı.
-- ⚠ YALNIZCA TAHSILAT_IYILESTIRME_V1 CANLIYA gectikten SONRA calistir.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay, ts)
SELECT v.adim, v.ne, v.neden, jsonb_build_object('aciklama', v.detay), now()
FROM (VALUES
  ('TAHSILAT_IYILESTIRME_V1',
   'İyileştirme Hedefleri "tahsilat" ve "gecikme" bayrakları ölçülen ödeme davranışına (bi_tahsilat) bağlandı.',
   'Kıyas kartı (TAHSILAT_KIYAS_V1) zaten ölçülene geçmişti; İyileştirme Hedefleri listesi hâlâ eski proxy (vade + overdue/ciro) ile bayrak koyuyordu — tutarsızdı ve gerçek geç ödeyicileri kaçırıyordu.',
   'Motor: iyilestirme-hedefleri JS .map — tahsilat bayrağı DSO>KRB ort DSO*1.15; gecikme bayrağı %geç>55 veya ort gecikme>15 gün. Kolonlar TAHSILAT_KIYAS_V1 ile sorguda mevcuttu. Tahsilat kaydı yoksa eski mantık fallback. node --check geçti.')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim);
SELECT adim, LEFT(ne,55) ne, ts::date FROM bi_insa_gunlugu WHERE adim = 'TAHSILAT_IYILESTIRME_V1';
