SET lock_timeout = '5s';

CREATE TABLE IF NOT EXISTS bi_tahmin (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  uretildi_at timestamptz NOT NULL DEFAULT now(),
  uretim_gun date NOT NULL,
  nesne text NOT NULL,
  varlik_tipi text NOT NULL,
  varlik_kodu text NOT NULL,
  hedef_donem date NOT NULL,
  ufuk_gun integer NOT NULL,
  yontem text NOT NULL DEFAULT 'taban',
  model_ad text NOT NULL,
  tahmin_deger numeric NOT NULL,
  alt_bant numeric, ust_bant numeric,
  tahmin_sinifi text,
  kovaryatlar jsonb, varsayimlar jsonb,
  UNIQUE (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,yontem,model_ad));

CREATE TABLE IF NOT EXISTS bi_tahmin_sonuc (
  tahmin_id uuid PRIMARY KEY REFERENCES bi_tahmin(id) ON DELETE CASCADE,
  gerceklesen numeric, hata numeric, mutlak_yuzde_hata numeric, bant_ici boolean,
  degerlendirildi_at timestamptz DEFAULT now(), kaynak text);

CREATE INDEX IF NOT EXISTS ix_tahmin_hedef ON bi_tahmin (tenant_id, hedef_donem, nesne, varlik_tipi);

-- KANON GERCEKLESME (tek kaynak; tum varlik tipleri tek view)
CREATE OR REPLACE VIEW v_gerceklesen_aylik AS
SELECT tenant_id::uuid tid,'musteri'::text varlik_tipi, musteri_kodu::text varlik_kodu,
       date_trunc('month',fatura_tarihi)::date donem,
       sum(COALESCE(miktar,0)) adet, sum(satir_tutar) ciro
  FROM bi_satis_faturalari WHERE satir_tutar>0 AND COALESCE(musteri_kodu,'')<>'' GROUP BY 1,2,3,4
UNION ALL
SELECT tenant_id::uuid,'marka', marka::text, date_trunc('month',fatura_tarihi)::date,
       sum(COALESCE(miktar,0)), sum(satir_tutar)
  FROM bi_satis_faturalari WHERE satir_tutar>0 AND COALESCE(marka,'')<>'' GROUP BY 1,2,3,4
UNION ALL
SELECT tenant_id::uuid,'kategori', kategori::text, date_trunc('month',fatura_tarihi)::date,
       sum(COALESCE(miktar,0)), sum(satir_tutar)
  FROM bi_satis_faturalari WHERE satir_tutar>0 AND COALESCE(kategori,'')<>'' GROUP BY 1,2,3,4
UNION ALL
SELECT tenant_id::uuid,'ebat', ebat::text, date_trunc('month',fatura_tarihi)::date,
       sum(COALESCE(miktar,0)), sum(satir_tutar)
  FROM bi_satis_faturalari WHERE satir_tutar>0 AND COALESCE(ebat,'')<>'' GROUP BY 1,2,3,4
UNION ALL
SELECT tenant_id::uuid,'TOPLAM','TOPLAM', date_trunc('month',fatura_tarihi)::date,
       sum(COALESCE(miktar,0)), sum(satir_tutar)
  FROM bi_satis_faturalari WHERE satir_tutar>0 GROUP BY 1,2,3,4;

-- DEGERLENDIRME: yalnizca KAPANMIS donemler
CREATE OR REPLACE FUNCTION bi_tahmin_degerlendir(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  INSERT INTO bi_tahmin_sonuc (tahmin_id,gerceklesen,hata,mutlak_yuzde_hata,bant_ici,kaynak)
  SELECT t.id, x.ger, t.tahmin_deger - x.ger,
         CASE WHEN x.ger <> 0 THEN abs(t.tahmin_deger - x.ger)/abs(x.ger)*100 END,
         CASE WHEN t.alt_bant IS NULL THEN NULL
              ELSE x.ger BETWEEN t.alt_bant AND t.ust_bant END,
         'v_gerceklesen_aylik'
    FROM bi_tahmin t
    LEFT JOIN v_gerceklesen_aylik g
      ON g.tid=t.tenant_id AND g.varlik_tipi=t.varlik_tipi
     AND g.varlik_kodu=t.varlik_kodu AND g.donem=t.hedef_donem
    CROSS JOIN LATERAL (SELECT COALESCE(
           CASE WHEN t.nesne='adet' THEN g.adet WHEN t.nesne='ciro' THEN g.ciro END, 0) AS ger) x
   WHERE t.nesne IN ('adet','ciro')
     AND (t.hedef_donem + interval '1 month')::date <= p_gun
     AND NOT EXISTS (SELECT 1 FROM bi_tahmin_sonuc s WHERE s.tahmin_id=t.id);
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- ISABET + YAYIN KAPISI (esikler veride)
CREATE OR REPLACE VIEW v_tahmin_isabet AS
SELECT t.tenant_id, t.nesne, t.varlik_tipi, COALESCE(t.tahmin_sinifi,'(sinifsiz)') sinif,
       t.ufuk_gun, t.yontem, t.model_ad, count(*) n,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY s.mutlak_yuzde_hata)::numeric,1) medyan_mape,
       round(avg(s.mutlak_yuzde_hata)::numeric,1) ort_mape,
       round(100.0*avg(CASE WHEN s.bant_ici THEN 1 ELSE 0 END)::numeric,1) bant_kapsama_pct
  FROM bi_tahmin t JOIN bi_tahmin_sonuc s ON s.tahmin_id=t.id
 GROUP BY 1,2,3,4,5,6,7;

CREATE TABLE IF NOT EXISTS bi_tahmin_yayin_esik (
  tenant_id uuid NOT NULL, nesne text NOT NULL,
  min_gozlem integer NOT NULL DEFAULT 12,
  max_medyan_mape numeric NOT NULL DEFAULT 25,
  min_bant_kapsama numeric NOT NULL DEFAULT 70,
  kaynak text NOT NULL DEFAULT 'tohum', guncellendi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, nesne));

CREATE OR REPLACE VIEW v_tahmin_yayin_kapisi AS
SELECT i.*, e.min_gozlem, e.max_medyan_mape,
       (i.n >= COALESCE(e.min_gozlem,12)
        AND i.medyan_mape <= COALESCE(e.max_medyan_mape,25)) AS yayinlanabilir
  FROM v_tahmin_isabet i
  LEFT JOIN bi_tahmin_yayin_esik e ON e.tenant_id=i.tenant_id AND e.nesne=i.nesne;
