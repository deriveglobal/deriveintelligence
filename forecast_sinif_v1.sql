SET lock_timeout = '5s';

CREATE TABLE IF NOT EXISTS bi_tahmin_sinif_esik (
  tenant_id uuid NOT NULL, varlik_tipi text NOT NULL,
  min_ay_yogun integer NOT NULL DEFAULT 36,
  min_ay_orta integer NOT NULL DEFAULT 12,
  max_cv_duzenli numeric NOT NULL DEFAULT 1.0,
  ritim_kati_terk numeric NOT NULL DEFAULT 3.0,
  min_gozlem_ritim integer NOT NULL DEFAULT 6,
  sessiz_ay_dusuk_gozlem integer NOT NULL DEFAULT 12,
  kaynak text NOT NULL DEFAULT 'tohum',
  guncellendi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, varlik_tipi));

CREATE TABLE IF NOT EXISTS bi_tahmin_sinif (
  tenant_id uuid NOT NULL, hesap_gun date NOT NULL,
  varlik_tipi text NOT NULL, varlik_kodu text NOT NULL,
  ay_say integer, ilk_alim date, son_alim date,
  ay_gecti numeric, tipik_aralik_ay numeric, ritim_kati numeric,
  cv_try numeric, cv_adet numeric, ciro numeric, ciro_pay_pct numeric,
  sinif text,
  PRIMARY KEY (tenant_id, hesap_gun, varlik_tipi, varlik_kodu));

CREATE INDEX IF NOT EXISTS ix_tahmin_sinif_tip
  ON bi_tahmin_sinif (tenant_id, hesap_gun, varlik_tipi, sinif);

CREATE OR REPLACE FUNCTION bi_tahmin_sinif_uret(p_gun date DEFAULT CURRENT_DATE)
RETURNS TABLE(tip text, satir integer) LANGUAGE plpgsql AS $fn$
DECLARE
  tipler   text[] := ARRAY['musteri','marka','kategori','ebat'];
  kolonlar text[] := ARRAY['musteri_kodu','marka','kategori','ebat'];
  i integer; n integer;
BEGIN
  FOR i IN 1..array_length(tipler,1) LOOP
    INSERT INTO bi_tahmin_sinif_esik (tenant_id, varlik_tipi)
      SELECT t.tid, tipler[i] FROM bi_tenant_listesi() t
      ON CONFLICT (tenant_id, varlik_tipi) DO NOTHING;
  END LOOP;

  DELETE FROM bi_tahmin_sinif WHERE hesap_gun = p_gun;

  FOR i IN 1..array_length(tipler,1) LOOP
    EXECUTE format($q$
      INSERT INTO bi_tahmin_sinif
        (tenant_id,hesap_gun,varlik_tipi,varlik_kodu,ay_say,ilk_alim,son_alim,
         ay_gecti,tipik_aralik_ay,ritim_kati,cv_try,cv_adet,ciro,ciro_pay_pct,sinif)
      WITH m AS (
        SELECT f.tenant_id::uuid AS tid, f.%1$I::text AS kod,
               date_trunc('month', f.fatura_tarihi)::date AS ay,
               sum(f.satir_tutar) AS t, sum(COALESCE(f.miktar,0)) AS q,
               min(f.fatura_tarihi) AS ilk_g, max(f.fatura_tarihi) AS son_g
          FROM bi_satis_faturalari f
         WHERE f.satir_tutar > 0 AND COALESCE(f.%1$I::text,'') <> ''
         GROUP BY 1,2,3),
      a AS (
        SELECT tid, kod, count(*)::int AS ay_say, min(ilk_g) AS ilk, max(son_g) AS son,
               sum(t) AS ciro,
               stddev_samp(t)/NULLIF(avg(t),0) AS cv_try,
               stddev_samp(q)/NULLIF(avg(q),0) AS cv_adet
          FROM m GROUP BY 1,2),
      b AS (
        SELECT a.*, ($1 - a.son)/30.0 AS ay_gecti,
               CASE WHEN a.ay_say > 1 THEN ((a.son - a.ilk)/30.0)/(a.ay_say - 1) END AS aralik,
               100*a.ciro/NULLIF(sum(a.ciro) OVER (PARTITION BY a.tid),0) AS pay
          FROM a),
      c AS (
        SELECT b.*, CASE WHEN b.aralik > 0 THEN b.ay_gecti/b.aralik END AS kat,
               e.min_ay_yogun, e.min_ay_orta, e.max_cv_duzenli,
               e.ritim_kati_terk, e.min_gozlem_ritim, e.sessiz_ay_dusuk_gozlem
          FROM b LEFT JOIN bi_tahmin_sinif_esik e
            ON e.tenant_id = b.tid AND e.varlik_tipi = %2$L)
      SELECT tid, $1, %2$L, kod, ay_say, ilk, son,
             round(ay_gecti,2), round(aralik,2), round(kat,2),
             round(cv_try,3), round(cv_adet,3), ciro, round(pay,3),
             CASE
               WHEN ay_say >= COALESCE(min_gozlem_ritim,6) AND kat IS NOT NULL
                    AND kat > COALESCE(ritim_kati_terk,3.0)                     THEN 'X terk'
               WHEN ay_say <  COALESCE(min_gozlem_ritim,6)
                    AND ay_gecti > COALESCE(sessiz_ay_dusuk_gozlem,12)          THEN 'X sessiz'
               WHEN ay_say >= COALESCE(min_ay_yogun,36)
                    AND COALESCE(cv_adet,9) <= COALESCE(max_cv_duzenli,1.0)     THEN 'A'
               WHEN ay_say >= COALESCE(min_ay_yogun,36)                         THEN 'B'
               WHEN ay_say >= COALESCE(min_ay_orta,12)                          THEN 'C'
               ELSE 'D' END
        FROM c
    $q$, kolonlar[i], tipler[i]) USING p_gun;
    GET DIAGNOSTICS n = ROW_COUNT;
    tip := tipler[i]; satir := n; RETURN NEXT;
  END LOOP;

  -- KAPSAMA KAPISI: siniflandirilan ciro = kanon ciro olmali (her tenant icin satir)
  DELETE FROM bi_foto_mutabakat WHERE foto_gun=p_gun AND kapi='sinif_kapsama_musteri';
  INSERT INTO bi_foto_mutabakat (tenant_id,foto_gun,kapi,olculen,referans,fark_pct,gecti,not_metin)
  SELECT t.tid, p_gun, 'sinif_kapsama_musteri', s.ciro, k.ciro,
         round(100*(s.ciro-k.ciro)/NULLIF(k.ciro,0),3),
         CASE WHEN s.ciro IS NULL OR COALESCE(k.ciro,0)=0 THEN NULL
              ELSE abs(100*(s.ciro-k.ciro)/k.ciro) <= 1 END,
         CASE WHEN s.ciro IS NULL THEN 'veri yok: siniflandirilmis musteri yok'
              WHEN COALESCE(k.ciro,0)=0 THEN 'veri yok: kanon ciro yok'
              ELSE 'musteri_kodu bos satirlar disarida kalirsa fark buyur' END
    FROM bi_tenant_listesi() t
    LEFT JOIN (SELECT tenant_id, sum(ciro) ciro FROM bi_tahmin_sinif
                WHERE hesap_gun=p_gun AND varlik_tipi='musteri' GROUP BY 1) s
           ON s.tenant_id = t.tid
    LEFT JOIN (SELECT tenant_id::uuid tid, sum(satir_tutar) ciro FROM bi_satis_faturalari
                WHERE satir_tutar>0 GROUP BY 1) k
           ON k.tid = t.tid;
  RETURN;
END $fn$;
