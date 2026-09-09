SET lock_timeout='5s';

CREATE TABLE IF NOT EXISTS bi_parametre (
  id bigserial PRIMARY KEY,
  ad text NOT NULL,
  kapsam_tenant uuid, kapsam_nesne text, kapsam_varlik_tipi text, kapsam_model text,
  deger numeric NOT NULL,
  tur text NOT NULL CHECK (tur IN ('kok','politika','turetilmis','tohum')),
  gecerli_baslangic date NOT NULL DEFAULT CURRENT_DATE,
  turetim_fn text, gozlem_say integer, kanit jsonb, gerekce text,
  yazildi_at timestamptz DEFAULT now());
CREATE INDEX IF NOT EXISTS ix_parametre_coz
  ON bi_parametre (ad, gecerli_baslangic DESC);

-- COZUCU: en ozel kazanir + as-of. KODDA VARSAYILAN YOK.
CREATE OR REPLACE FUNCTION bi_parametre_coz(
  p_ad text, p_tenant uuid DEFAULT NULL, p_nesne text DEFAULT NULL,
  p_varlik_tipi text DEFAULT NULL, p_model text DEFAULT NULL,
  p_as_of date DEFAULT CURRENT_DATE)
RETURNS numeric LANGUAGE plpgsql STABLE AS $fn$
DECLARE v numeric;
BEGIN
  SELECT deger INTO v FROM bi_parametre
   WHERE ad = p_ad AND gecerli_baslangic <= p_as_of
     AND (kapsam_tenant      IS NULL OR kapsam_tenant      = p_tenant)
     AND (kapsam_nesne       IS NULL OR kapsam_nesne       = p_nesne)
     AND (kapsam_varlik_tipi IS NULL OR kapsam_varlik_tipi = p_varlik_tipi)
     AND (kapsam_model       IS NULL OR kapsam_model       = p_model)
   ORDER BY (kapsam_tenant IS NOT NULL)::int + (kapsam_nesne IS NOT NULL)::int
          + (kapsam_varlik_tipi IS NOT NULL)::int + (kapsam_model IS NOT NULL)::int DESC,
          gecerli_baslangic DESC, id DESC
   LIMIT 1;
  IF v IS NULL THEN
    RAISE EXCEPTION 'bi_parametre_coz: "%" cozulemedi (tenant=%, nesne=%, tip=%, model=%, as_of=%). Kodda varsayilan yok.',
      p_ad,p_tenant,p_nesne,p_varlik_tipi,p_model,p_as_of;
  END IF;
  RETURN v;
END $fn$;

-- BORC ENVANTERI: bugunku sayilar oldugu gibi, durust gerekceyle
INSERT INTO bi_parametre (ad,deger,tur,gerekce) VALUES
 ('kapi_min_gozlem',        12, 'tohum','elle konuldu; iki modeli ayirt etmek icin gereken orneklemden turetilmeli'),
 ('kapi_min_donem',         12, 'tohum','elle konuldu; kesit genisligi zamansal kanit yerine gecmesin diye eklendi'),
 ('kapi_min_bantli_n',      10, 'tohum','KODDA kaldi (v_tahmin_yayin_kapisi); tasinacak'),
 ('kapi_max_medyan_mape',   25, 'politika','yayinlanan tahminin izin verilen hata tavani — RISK ISTAHI, ogrenilmez'),
 ('kapi_min_bant_kapsama',  70, 'politika','bandin tutmasi gereken asgari oran — ogrenilmez'),
 ('kapi_max_bant_kapsama',  95, 'politika','bilgi tasimayan genis bandi engeller — ogrenilmez'),
 ('bant_hedef_kapsama',   0.80, 'politika','urun vaadi; nominal bundan TURETILIR'),
 ('bant_muhur_ay',          12, 'tohum','elle konuldu'),
 ('sampiyon_marj',        0.10, 'tohum','elle konuldu; MAPE nin o n deki orneklem hatasindan turetilmeli'),
 ('sampiyon_min_pencere',    3, 'kok','tek pencere gurultudur — asgari bagimsiz pencere sayisi'),
 ('sampiyon_max_skor',      60, 'politika','hicbir aday kabul edilebilir degilse sampiyon ilan edilmez'),
 ('mutabakat_max_fark_pct',  5, 'politika','kapinin acik sayilmasi icin izin verilen sapma'),
 ('cekirdek_max_lag',       11, 'tohum','elle konuldu; kumulatifin duzlestigi yerden turetilmeli'),
 ('sinyal_min_ciro_pay',    1.0,'tohum','materyalite tabani; elle konuldu'),
 ('sinyal_min_kayma_pct',  15.0,'tohum','elle konuldu'),
 ('backtest_ay_geri',       48, 'tohum','elle konuldu'),
 ('sinif_min_ay_yogun',     36, 'tohum','elle konuldu'),
 ('sinif_min_ay_orta',      12, 'tohum','elle konuldu'),
 ('sinif_max_cv_duzenli',  1.0, 'tohum','elle konuldu'),
 ('sinif_ritim_kati_terk',  9.0, 'turetilmis','kalibrasyon egrisinden okundu (geri donus %%14.8 -> %%3.4 esiginde)'),
 ('sinif_min_gozlem_ritim',  6, 'tohum','elle konuldu'),
 ('kok_isinma_tolerans',   2.0, 'kok','isinma bitisi: yuruyen hata, uzun-donem medyaninin bu katinin altina indigi ilk ay')
ON CONFLICT DO NOTHING;

-- ILK DONUSTURME: isinma_ay artik veriden turer
CREATE OR REPLACE FUNCTION bi_isinma_turet()
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE tol numeric; v integer;
BEGIN
  tol := bi_parametre_coz('kok_isinma_tolerans');
  WITH e AS (
    SELECT t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.model_ad,t.hedef_donem,
           s.mutlak_yuzde_hata ape,
           row_number() OVER w rn, count(*) OVER w n,
           avg(s.mutlak_yuzde_hata) OVER (PARTITION BY t.tenant_id,t.nesne,t.varlik_tipi,
                 t.varlik_kodu,t.model_ad ORDER BY t.hedef_donem
                 ROWS BETWEEN CURRENT ROW AND 5 FOLLOWING) yuruyen6
      FROM bi_tahmin t JOIN bi_tahmin_sonuc s ON s.tahmin_id=t.id
     WHERE t.kosum='backtest' AND s.mutlak_yuzde_hata IS NOT NULL
    WINDOW w AS (PARTITION BY t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.model_ad
                 ORDER BY t.hedef_donem)),
  son AS (
    SELECT tenant_id,nesne,varlik_tipi,varlik_kodu,model_ad,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY ape) son_med, max(n) n
      FROM e WHERE rn > n-12 GROUP BY 1,2,3,4,5),
  ilk AS (
    SELECT e.tenant_id,e.nesne,e.varlik_tipi,e.varlik_kodu,e.model_ad,
           min(e.hedef_donem) FILTER (WHERE e.yuruyen6 <= tol*son.son_med) ilk_kararli,
           min(e.hedef_donem) seri_ilk, max(son.son_med) son_med, max(son.n) n
      FROM e JOIN son USING (tenant_id,nesne,varlik_tipi,varlik_kodu,model_ad)
     GROUP BY 1,2,3,4,5)
  INSERT INTO bi_parametre (ad,kapsam_tenant,kapsam_nesne,kapsam_varlik_tipi,kapsam_model,
                            deger,tur,turetim_fn,gozlem_say,kanit,gerekce)
  SELECT 'isinma_ay', tenant_id, nesne, varlik_tipi, model_ad,
         GREATEST(0, (extract(year FROM age(ilk_kararli,seri_ilk))*12
                    + extract(month FROM age(ilk_kararli,seri_ilk)))::int),
         'turetilmis','bi_isinma_turet', n,
         jsonb_build_object('seri_ilk',seri_ilk,'ilk_kararli',ilk_kararli,
                            'son_medyan_ape',round(son_med::numeric,1),'tolerans',tol),
         'yuruyen 6-ay ortalama hata, uzun-donem medyaninin tolerans katinin altina ilk indigi ay'
    FROM ilk WHERE ilk_kararli IS NOT NULL AND varlik_kodu='TOPLAM';
  GET DIAGNOSTICS v=ROW_COUNT; RETURN v;
END $fn$;
