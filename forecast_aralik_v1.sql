-- ARALIK SKORU (kapsama-farkinda uygun skorlama; dusuk = iyi)
CREATE OR REPLACE VIEW v_tahmin_aralik_skoru AS
SELECT t.id, t.tenant_id, t.nesne, t.varlik_tipi, t.varlik_kodu, t.ufuk_gun, t.model_ad,
       t.hedef_donem, s.gerceklesen, s.bant_ici, s.mutlak_yuzde_hata,
       ((t.ust_bant - t.alt_bant)
        + CASE WHEN s.gerceklesen < t.alt_bant
               THEN (2/(1-b.hedef_kapsama))*(t.alt_bant - s.gerceklesen) ELSE 0 END
        + CASE WHEN s.gerceklesen > t.ust_bant
               THEN (2/(1-b.hedef_kapsama))*(s.gerceklesen - t.ust_bant) ELSE 0 END
       ) / NULLIF(abs(s.gerceklesen),0) AS aralik_skoru
  FROM bi_tahmin t
  JOIN bi_tahmin_sonuc s ON s.tahmin_id = t.id
  JOIN bi_tahmin_bant_ayar b
    ON b.tenant_id=t.tenant_id AND b.nesne=t.nesne AND b.varlik_tipi=t.varlik_tipi
   AND b.varlik_kodu=t.varlik_kodu AND b.ufuk_gun=t.ufuk_gun AND b.model_ad=t.model_ad
 WHERE t.alt_bant IS NOT NULL AND s.gerceklesen IS NOT NULL;

-- SAMPIYON v2: olcut secilebilir (mape | aralik)
ALTER TABLE bi_tahmin_sampiyon ADD COLUMN IF NOT EXISTS olcut text NOT NULL DEFAULT 'mape';
ALTER TABLE bi_tahmin_sampiyon ADD COLUMN IF NOT EXISTS kapsama_pct numeric;

CREATE OR REPLACE FUNCTION bi_tahmin_sampiyon_sec_aralik(p_min_donem integer DEFAULT 10)
RETURNS TABLE(hucre text, mape_sampiyon text, aralik_sampiyon text,
              mape_kapsama numeric, aralik_kapsama numeric) LANGUAGE sql AS $fn$
WITH p AS (
  SELECT tenant_id,nesne,varlik_tipi,varlik_kodu,model_ad,
         count(*) n,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY aralik_skoru) skor,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY mutlak_yuzde_hata) mape,
         round(100.0*avg(CASE WHEN bant_ici THEN 1 ELSE 0 END)::numeric,1) kapsama
    FROM v_tahmin_aralik_skoru
   GROUP BY 1,2,3,4,5 HAVING count(*) >= p_min_donem),
a AS (SELECT DISTINCT ON (tenant_id,nesne,varlik_tipi,varlik_kodu) * FROM p
       ORDER BY tenant_id,nesne,varlik_tipi,varlik_kodu, skor ASC),
m AS (SELECT DISTINCT ON (tenant_id,nesne,varlik_tipi,varlik_kodu) * FROM p
       ORDER BY tenant_id,nesne,varlik_tipi,varlik_kodu, mape ASC)
SELECT m.varlik_kodu||' / '||m.nesne, m.model_ad, a.model_ad, m.kapsama, a.kapsama
  FROM m JOIN a USING (tenant_id,nesne,varlik_tipi,varlik_kodu)
 WHERE m.varlik_tipi='segment';
$fn$;

-- YAYIN KAPISINA KAPSAMA SARTI (kolon vardi, kullanilmiyordu)
DROP VIEW IF EXISTS v_tahmin_yayin_kapisi;
CREATE VIEW v_tahmin_yayin_kapisi AS
SELECT i.*, e.min_gozlem, e.min_donem, e.max_medyan_mape, e.min_bant_kapsama,
       (i.n >= COALESCE(e.min_gozlem,12)
        AND i.donem_say >= COALESCE(e.min_donem,12)
        AND i.medyan_mape <= COALESCE(e.max_medyan_mape,25)
        AND COALESCE(i.bant_kapsama_pct,0) >= COALESCE(e.min_bant_kapsama,70)) AS yayinlanabilir
  FROM v_tahmin_isabet i
  LEFT JOIN bi_tahmin_yayin_esik e ON e.tenant_id=i.tenant_id AND e.nesne=i.nesne;
