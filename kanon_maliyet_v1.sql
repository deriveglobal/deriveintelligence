-- ============================================================================
-- KANON MALİYET V1 — parallel run (additive, geri alınabilir, mevcutu BOZMAZ)
-- Akış yöntemi: maliyet(SKU,ay) = o ay SATILAN adet kadar, en son alım lotlarının
--   adet-ağırlıklı ortalaması (sınır lotu KISMİ ağırlık). Sihirli N yok (N=satılan adet).
-- Mevcut birim_maliyet / marj_pct'e DOKUNMAZ; yeni kolonlara yazar.
-- Sadece MAL_GIRISI/ACILIS hareketleri (canlı fonksiyonla aynı filtre).
-- Çalıştırma:  cat kanon_maliyet_v1.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- Geri alma:   ALTER TABLE bi_marj_atom DROP COLUMN birim_maliyet_kanon, DROP COLUMN marj_pct_kanon, DROP COLUMN kanon_kapsam;
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 1) yeni kolonlar (idempotent)
ALTER TABLE bi_marj_atom ADD COLUMN IF NOT EXISTS birim_maliyet_kanon numeric;
ALTER TABLE bi_marj_atom ADD COLUMN IF NOT EXISTS marj_pct_kanon numeric;
ALTER TABLE bi_marj_atom ADD COLUMN IF NOT EXISTS kanon_kapsam numeric;  -- son alımlar satılanı %kaç karşıladı

-- 2) akış maliyetini hesapla + yaz (yalnız kanon kolonlarına)
WITH lots AS (
  SELECT a.kalem_kodu, a.ay, a.adet::numeric sold_qty,
         h.giris::numeric giris,
         (h.giris_tutari/NULLIF(h.giris,0))::numeric uc,
         sum(h.giris) OVER (PARTITION BY a.kalem_kodu, a.ay
                            ORDER BY h.belge_tarihi DESC, h.ctid DESC
                            ROWS UNBOUNDED PRECEDING) run
  FROM bi_marj_atom a
  JOIN bi_stok_hareket h
    ON h.tenant_id = a.tenant_id
   AND h.kalem_kodu = a.kalem_kodu
   AND h.hareket_sinifi IN ('MAL_GIRISI','ACILIS')
   AND h.giris > 0 AND h.giris_tutari > 0
   AND h.belge_tarihi < a.ay + interval '1 month'
  WHERE a.tenant_id = :T::uuid AND a.adet > 0
),
used AS (
  SELECT kalem_kodu, ay, sold_qty, uc,
         greatest(0, least(giris, sold_qty - (run - giris)))::numeric uq
  FROM lots
),
kanon AS (
  SELECT kalem_kodu, ay,
         sum(uc*uq)/NULLIF(sum(uq),0) km,
         sum(uq) kaps, max(sold_qty) sq
  FROM used WHERE uq > 0 GROUP BY 1,2
)
UPDATE bi_marj_atom a
   SET birim_maliyet_kanon = round(k.km),
       marj_pct_kanon = round(100*(1 - k.km / NULLIF(a.ciro/NULLIF(a.adet,0),0)), 1),
       kanon_kapsam = round(100 * k.kaps / NULLIF(k.sq,0))
  FROM kanon k
 WHERE a.tenant_id = :T::uuid AND a.kalem_kodu = k.kalem_kodu AND a.ay = k.ay;

-- 3) ÖZET — eski (son-ay) vs kanon (akış): kaç satır, ne kadar kaydı, kaç işaret değişti
SELECT
  count(*) FILTER (WHERE birim_maliyet_kanon IS NOT NULL) kanon_dolu,
  count(*) FILTER (WHERE birim_maliyet_kanon IS NULL)     kanon_bos,
  round(avg(abs(marj_pct - marj_pct_kanon)) FILTER (WHERE marj_pct_kanon IS NOT NULL),1) ort_kayma_puan,
  count(*) FILTER (WHERE sign(marj_pct)<>sign(marj_pct_kanon) AND marj_pct_kanon IS NOT NULL) isaret_degisen,
  round(avg(kanon_kapsam) FILTER (WHERE kanon_kapsam IS NOT NULL)) ort_kapsam_pct
FROM bi_marj_atom WHERE tenant_id = :T::uuid AND ay >= date_trunc('month',CURRENT_DATE) - interval '3 month';

-- 4) CİRO-AĞIRLIKLI aylık marj: eski vs kanon (grafikteki "çöküş" kanonla nasıl?)
SELECT to_char(ay,'YYYY-MM') ay,
       round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) eski_marj,
       round(100*sum(ciro - adet*birim_maliyet_kanon)/NULLIF(sum(ciro) FILTER (WHERE birim_maliyet_kanon IS NOT NULL),0),1) kanon_marj
FROM bi_marj_atom
WHERE tenant_id = :T::uuid AND ay >= date_trunc('month',CURRENT_DATE) - interval '12 month'
GROUP BY ay ORDER BY ay;

-- 5) Bridgestone örnek (doğrulama)
SELECT kalem_kodu, round(birim_maliyet) eski_mal, marj_pct eski_marj,
       round(birim_maliyet_kanon) kanon_mal, marj_pct_kanon kanon_marj, kanon_kapsam
FROM bi_marj_atom
WHERE tenant_id = :T::uuid AND ay='2026-07-01' AND marka='BRIDGESTONE'
ORDER BY ciro DESC LIMIT 6;
