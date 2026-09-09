-- KAYAN3 BACKTEST. Hedef: h ayinda biten 3 aylik pencere.
-- u ay ufukta en son bilinen pencere h-u'da biter. Gecikmeler CAKISMASIN diye
-- 3 ay adimli: r1=h-u, r2=h-u-3, r3=h-u-6.  Mevsimsel: s0=h-12.
-- Deftere yontem='kayan3' ile yazilir; aylik tahminlerle karismaz (kimlik anahtarinda yontem var).
CREATE OR REPLACE FUNCTION bi_tahmin_backtest_kayan3(
  p_ay_geri integer DEFAULT 48, p_son_hedef date DEFAULT NULL,
  p_tipler text[] DEFAULT ARRAY['TOPLAM','segment','kategori','tahsilat','tahsilat_grup'],
  p_ufuk_ay integer DEFAULT 3)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer; ilk date; son date; u integer;
BEGIN
  u   := p_ufuk_ay;
  son := COALESCE(p_son_hedef,(date_trunc('month',CURRENT_DATE) - interval '1 month')::date);
  ilk := (son - ((p_ay_geri-1) || ' months')::interval)::date;

  INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                         ufuk_gun,yontem,model_ad,tahmin_deger,kosum)
  WITH k AS (SELECT * FROM mv_gerceklesen_kayan3 WHERE ay_say=3),
  h AS (SELECT DISTINCT tid,varlik_tipi,varlik_kodu,donem AS hedef
          FROM k WHERE varlik_tipi = ANY(p_tipler) AND donem BETWEEN ilk AND son
            AND (ciro > 0 OR adet > 0)),
  b AS (
    SELECT h.tid,h.varlik_tipi,h.varlik_kodu,h.hedef,n.nesne,
           CASE WHEN n.nesne='adet' THEN r1.adet ELSE r1.ciro END x1,
           CASE WHEN n.nesne='adet' THEN r2.adet ELSE r2.ciro END x2,
           CASE WHEN n.nesne='adet' THEN r3.adet ELSE r3.ciro END x3,
           CASE WHEN n.nesne='adet' THEN s0.adet ELSE s0.ciro END y0,
           CASE WHEN n.nesne='adet' THEN t1.adet ELSE t1.ciro END z1,
           CASE WHEN n.nesne='adet' THEN t2.adet ELSE t2.ciro END z2,
           CASE WHEN n.nesne='adet' THEN t3.adet ELSE t3.ciro END z3
      FROM h CROSS JOIN (VALUES ('adet'),('ciro')) n(nesne)
      LEFT JOIN k r1 ON r1.tid=h.tid AND r1.varlik_tipi=h.varlik_tipi
        AND r1.varlik_kodu=h.varlik_kodu AND r1.donem=(h.hedef-(u||' months')::interval)::date
      LEFT JOIN k r2 ON r2.tid=h.tid AND r2.varlik_tipi=h.varlik_tipi
        AND r2.varlik_kodu=h.varlik_kodu AND r2.donem=(h.hedef-((u+3)||' months')::interval)::date
      LEFT JOIN k r3 ON r3.tid=h.tid AND r3.varlik_tipi=h.varlik_tipi
        AND r3.varlik_kodu=h.varlik_kodu AND r3.donem=(h.hedef-((u+6)||' months')::interval)::date
      LEFT JOIN k s0 ON s0.tid=h.tid AND s0.varlik_tipi=h.varlik_tipi
        AND s0.varlik_kodu=h.varlik_kodu AND s0.donem=(h.hedef-interval '12 months')::date
      LEFT JOIN k t1 ON t1.tid=h.tid AND t1.varlik_tipi=h.varlik_tipi
        AND t1.varlik_kodu=h.varlik_kodu AND t1.donem=(h.hedef-((12+u)||' months')::interval)::date
      LEFT JOIN k t2 ON t2.tid=h.tid AND t2.varlik_tipi=h.varlik_tipi
        AND t2.varlik_kodu=h.varlik_kodu AND t2.donem=(h.hedef-((15+u)||' months')::interval)::date
      LEFT JOIN k t3 ON t3.tid=h.tid AND t3.varlik_tipi=h.varlik_tipi
        AND t3.varlik_kodu=h.varlik_kodu AND t3.donem=(h.hedef-((18+u)||' months')::interval)::date)
  SELECT b.tid,
         (b.hedef - ((u-1)||' months')::interval)::date - 1,
         b.nesne,b.varlik_tipi,b.varlik_kodu,b.hedef, u*30,'kayan3',m.model_ad,m.deger,'backtest'
    FROM b CROSS JOIN LATERAL (VALUES
      ('naif', b.x1), ('mevsimsel_naif', b.y0),
      ('hareketli_ort_3',(COALESCE(b.x1,0)+COALESCE(b.x2,0)+COALESCE(b.x3,0))
        / NULLIF((b.x1 IS NOT NULL)::int+(b.x2 IS NOT NULL)::int+(b.x3 IS NOT NULL)::int,0)),
      ('mevsimsel_trend', b.y0 * (COALESCE(b.x1,0)+COALESCE(b.x2,0)+COALESCE(b.x3,0))
        / NULLIF(COALESCE(b.z1,0)+COALESCE(b.z2,0)+COALESCE(b.z3,0),0))
    ) m(model_ad,deger)
    JOIN bi_tahmin_model mm ON mm.model_ad=m.model_ad AND mm.aktif
   WHERE m.deger IS NOT NULL AND m.deger > 0
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- Kayan3'e ozel puanlayici. Mevcut bi_tahmin_degerlendir'e DOKUNMUYOR,
-- ayni bi_tahmin_sonuc tablosuna yaziyor -> v_tahmin_isabet ve kapi otomatik gorur.
CREATE OR REPLACE FUNCTION bi_tahmin_degerlendir_kayan3()
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  INSERT INTO bi_tahmin_sonuc (tahmin_id,gerceklesen,hata,mutlak_yuzde_hata,bant_ici,kaynak)
  SELECT t.id, g.d, t.tahmin_deger - g.d,
         abs(t.tahmin_deger - g.d)/g.d*100,
         CASE WHEN t.alt_bant IS NULL THEN NULL ELSE (g.d BETWEEN t.alt_bant AND t.ust_bant) END,
         'kayan3'
    FROM bi_tahmin t
    JOIN LATERAL (SELECT CASE WHEN t.nesne='adet' THEN k.adet ELSE k.ciro END::numeric d
                    FROM mv_gerceklesen_kayan3 k
                   WHERE k.tid=t.tenant_id AND k.varlik_tipi=t.varlik_tipi
                     AND k.varlik_kodu=t.varlik_kodu AND k.donem=t.hedef_donem
                     AND k.ay_say=3) g ON g.d > 0
   WHERE t.yontem='kayan3'
     AND t.hedef_donem < date_trunc('month',CURRENT_DATE)::date
     AND NOT EXISTS (SELECT 1 FROM bi_tahmin_sonuc s WHERE s.tahmin_id=t.id);
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;
