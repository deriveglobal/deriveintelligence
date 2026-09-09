SET lock_timeout = '5s';

-- 0) kosum tipi: backtest / canli / golge
ALTER TABLE bi_tahmin ADD COLUMN IF NOT EXISTS kosum text NOT NULL DEFAULT 'canli';
UPDATE bi_tahmin SET kosum='backtest' WHERE kosum='canli' AND model_ad='mevsimsel_naif';

-- 1) MODEL KAYIT DEFTERI (aday eklemek = satir eklemek, deploy degil)
CREATE TABLE IF NOT EXISTS bi_tahmin_model (
  model_ad text PRIMARY KEY, aile text, aciklama text,
  aktif boolean NOT NULL DEFAULT true, eklendi_at timestamptz DEFAULT now());
INSERT INTO bi_tahmin_model (model_ad,aile,aciklama) VALUES
 ('naif','naif','Gecen ayin degeri'),
 ('mevsimsel_naif','naif','Gecen yil ayni ayin degeri'),
 ('hareketli_ort_3','duzlestirme','Son uc ayin ortalamasi'),
 ('mevsimsel_trend','naif+trend','Gecen yil ayni ay x (son 3 ay / bir yil onceki ayni 3 ay)')
ON CONFLICT DO NOTHING;

-- 2) GERCEKLESME materyalize (backtest icin; view her seferinde 376k satiri taramasin)
DROP MATERIALIZED VIEW IF EXISTS mv_gerceklesen_aylik CASCADE;
CREATE MATERIALIZED VIEW mv_gerceklesen_aylik AS SELECT * FROM v_gerceklesen_aylik;
CREATE UNIQUE INDEX ux_mv_gerc ON mv_gerceklesen_aylik (tid, varlik_tipi, varlik_kodu, donem);

-- 3) ROLLING-ORIGIN KOSUCUSU
CREATE OR REPLACE FUNCTION bi_tahmin_backtest(p_ay_geri integer DEFAULT 48)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer; ilk date; son date;
BEGIN
  son := (date_trunc('month',CURRENT_DATE) - interval '1 month')::date;
  ilk := (date_trunc('month',CURRENT_DATE) - (p_ay_geri || ' months')::interval)::date;

  INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                         ufuk_gun,yontem,model_ad,tahmin_deger,kosum)
  WITH h AS (
    SELECT DISTINCT tid,varlik_tipi,varlik_kodu,donem AS hedef
      FROM mv_gerceklesen_aylik
     WHERE varlik_tipi IN ('TOPLAM','segment','kategori')
       AND donem BETWEEN ilk AND son),
  b AS (
    SELECT h.tid,h.varlik_tipi,h.varlik_kodu,h.hedef,n.nesne,
           CASE WHEN n.nesne='adet' THEN m1.adet  ELSE m1.ciro  END l1,
           CASE WHEN n.nesne='adet' THEN m2.adet  ELSE m2.ciro  END l2,
           CASE WHEN n.nesne='adet' THEN m3.adet  ELSE m3.ciro  END l3,
           CASE WHEN n.nesne='adet' THEN m12.adet ELSE m12.ciro END l12,
           CASE WHEN n.nesne='adet' THEN m13.adet ELSE m13.ciro END l13,
           CASE WHEN n.nesne='adet' THEN m14.adet ELSE m14.ciro END l14,
           CASE WHEN n.nesne='adet' THEN m15.adet ELSE m15.ciro END l15
      FROM h CROSS JOIN (VALUES ('adet'),('ciro')) n(nesne)
      LEFT JOIN mv_gerceklesen_aylik m1  ON m1.tid=h.tid  AND m1.varlik_tipi=h.varlik_tipi
             AND m1.varlik_kodu=h.varlik_kodu  AND m1.donem =(h.hedef-interval '1 month')::date
      LEFT JOIN mv_gerceklesen_aylik m2  ON m2.tid=h.tid  AND m2.varlik_tipi=h.varlik_tipi
             AND m2.varlik_kodu=h.varlik_kodu  AND m2.donem =(h.hedef-interval '2 months')::date
      LEFT JOIN mv_gerceklesen_aylik m3  ON m3.tid=h.tid  AND m3.varlik_tipi=h.varlik_tipi
             AND m3.varlik_kodu=h.varlik_kodu  AND m3.donem =(h.hedef-interval '3 months')::date
      LEFT JOIN mv_gerceklesen_aylik m12 ON m12.tid=h.tid AND m12.varlik_tipi=h.varlik_tipi
             AND m12.varlik_kodu=h.varlik_kodu AND m12.donem=(h.hedef-interval '12 months')::date
      LEFT JOIN mv_gerceklesen_aylik m13 ON m13.tid=h.tid AND m13.varlik_tipi=h.varlik_tipi
             AND m13.varlik_kodu=h.varlik_kodu AND m13.donem=(h.hedef-interval '13 months')::date
      LEFT JOIN mv_gerceklesen_aylik m14 ON m14.tid=h.tid AND m14.varlik_tipi=h.varlik_tipi
             AND m14.varlik_kodu=h.varlik_kodu AND m14.donem=(h.hedef-interval '14 months')::date
      LEFT JOIN mv_gerceklesen_aylik m15 ON m15.tid=h.tid AND m15.varlik_tipi=h.varlik_tipi
             AND m15.varlik_kodu=h.varlik_kodu AND m15.donem=(h.hedef-interval '15 months')::date)
  SELECT b.tid,(b.hedef-1),b.nesne,b.varlik_tipi,b.varlik_kodu,b.hedef,30,'taban',
         m.model_ad,m.deger,'backtest'
    FROM b
    CROSS JOIN LATERAL (VALUES
      ('naif',            b.l1),
      ('mevsimsel_naif',  b.l12),
      ('hareketli_ort_3',
        (COALESCE(b.l1,0)+COALESCE(b.l2,0)+COALESCE(b.l3,0))
        / NULLIF((b.l1 IS NOT NULL)::int+(b.l2 IS NOT NULL)::int+(b.l3 IS NOT NULL)::int,0)),
      ('mevsimsel_trend',
        b.l12 * (COALESCE(b.l1,0)+COALESCE(b.l2,0)+COALESCE(b.l3,0))
              / NULLIF(COALESCE(b.l13,0)+COALESCE(b.l14,0)+COALESCE(b.l15,0),0))
    ) m(model_ad,deger)
    JOIN bi_tahmin_model mm ON mm.model_ad=m.model_ad AND mm.aktif
   WHERE m.deger IS NOT NULL AND m.deger >= 0
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- 4) SAMPIYON SECIMI (marj + min donem kurali)
CREATE TABLE IF NOT EXISTS bi_tahmin_sampiyon (
  tenant_id uuid NOT NULL, nesne text NOT NULL, varlik_tipi text NOT NULL,
  varlik_kodu text NOT NULL, ufuk_gun integer NOT NULL,
  model_ad text NOT NULL, medyan_mape numeric, n integer, donem_say integer,
  onceki_model text, onceki_mape numeric, secildi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun));

CREATE OR REPLACE FUNCTION bi_tahmin_sampiyon_sec(
  p_min_donem integer DEFAULT 12, p_marj numeric DEFAULT 0.10)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  INSERT INTO bi_tahmin_sampiyon
    (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun,model_ad,medyan_mape,n,donem_say)
  SELECT DISTINCT ON (t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.ufuk_gun)
         t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.ufuk_gun,t.model_ad,
         round(percentile_cont(0.5) WITHIN GROUP (ORDER BY s.mutlak_yuzde_hata)::numeric,2),
         count(*)::int, count(DISTINCT t.hedef_donem)::int
    FROM bi_tahmin t JOIN bi_tahmin_sonuc s ON s.tahmin_id=t.id
   WHERE t.kosum='backtest' AND s.mutlak_yuzde_hata IS NOT NULL
   GROUP BY t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.ufuk_gun,t.model_ad
  HAVING count(DISTINCT t.hedef_donem) >= p_min_donem
   ORDER BY t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.ufuk_gun,
            percentile_cont(0.5) WITHIN GROUP (ORDER BY s.mutlak_yuzde_hata) ASC
  ON CONFLICT (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun) DO UPDATE SET
     onceki_model = bi_tahmin_sampiyon.model_ad,
     onceki_mape  = bi_tahmin_sampiyon.medyan_mape,
     model_ad     = EXCLUDED.model_ad,
     medyan_mape  = EXCLUDED.medyan_mape,
     n            = EXCLUDED.n,
     donem_say    = EXCLUDED.donem_say,
     secildi_at   = now()
   WHERE EXCLUDED.medyan_mape < bi_tahmin_sampiyon.medyan_mape * (1 - p_marj);
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;
