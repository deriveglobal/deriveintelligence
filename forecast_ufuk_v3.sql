-- DUZELTME: uretim_gun = kullanilan son ayin son gunu. u=2, h=2026-09 -> 2026-07-31
-- (eskisi 2026-06-30 yaziyordu; sayi degil, kunye yanlisti)
CREATE OR REPLACE FUNCTION bi_tahmin_backtest_ufuk(
  p_ay_geri integer DEFAULT 48, p_son_hedef date DEFAULT NULL,
  p_tipler text[] DEFAULT ARRAY['TOPLAM','segment','kategori','tahsilat','tahsilat_grup'],
  p_ufuk_ay integer DEFAULT 1)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer; ilk date; son date; u integer;
BEGIN
  u   := p_ufuk_ay;
  son := COALESCE(p_son_hedef,(date_trunc('month',CURRENT_DATE) - interval '1 month')::date);
  ilk := (son - ((p_ay_geri-1) || ' months')::interval)::date;
  INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                         ufuk_gun,yontem,model_ad,tahmin_deger,kosum)
  WITH h AS (SELECT DISTINCT tid,varlik_tipi,varlik_kodu,donem AS hedef
               FROM mv_gerceklesen_aylik
              WHERE varlik_tipi = ANY(p_tipler) AND donem BETWEEN ilk AND son),
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
      LEFT JOIN mv_gerceklesen_aylik r1 ON r1.tid=h.tid AND r1.varlik_tipi=h.varlik_tipi
        AND r1.varlik_kodu=h.varlik_kodu AND r1.donem=(h.hedef-(u||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik r2 ON r2.tid=h.tid AND r2.varlik_tipi=h.varlik_tipi
        AND r2.varlik_kodu=h.varlik_kodu AND r2.donem=(h.hedef-((u+1)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik r3 ON r3.tid=h.tid AND r3.varlik_tipi=h.varlik_tipi
        AND r3.varlik_kodu=h.varlik_kodu AND r3.donem=(h.hedef-((u+2)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik s0 ON s0.tid=h.tid AND s0.varlik_tipi=h.varlik_tipi
        AND s0.varlik_kodu=h.varlik_kodu AND s0.donem=(h.hedef-interval '12 months')::date
      LEFT JOIN mv_gerceklesen_aylik t1 ON t1.tid=h.tid AND t1.varlik_tipi=h.varlik_tipi
        AND t1.varlik_kodu=h.varlik_kodu AND t1.donem=(h.hedef-((12+u)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik t2 ON t2.tid=h.tid AND t2.varlik_tipi=h.varlik_tipi
        AND t2.varlik_kodu=h.varlik_kodu AND t2.donem=(h.hedef-((13+u)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik t3 ON t3.tid=h.tid AND t3.varlik_tipi=h.varlik_tipi
        AND t3.varlik_kodu=h.varlik_kodu AND t3.donem=(h.hedef-((14+u)||' months')::interval)::date)
  SELECT b.tid,
         (b.hedef - ((u-1)||' months')::interval)::date - 1,
         b.nesne,b.varlik_tipi,b.varlik_kodu,b.hedef, u*30,'taban',m.model_ad,m.deger,'backtest'
    FROM b CROSS JOIN LATERAL (VALUES
      ('naif', b.x1), ('mevsimsel_naif', b.y0),
      ('hareketli_ort_3',(COALESCE(b.x1,0)+COALESCE(b.x2,0)+COALESCE(b.x3,0))
        / NULLIF((b.x1 IS NOT NULL)::int+(b.x2 IS NOT NULL)::int+(b.x3 IS NOT NULL)::int,0)),
      ('mevsimsel_trend', b.y0 * (COALESCE(b.x1,0)+COALESCE(b.x2,0)+COALESCE(b.x3,0))
        / NULLIF(COALESCE(b.z1,0)+COALESCE(b.z2,0)+COALESCE(b.z3,0),0))
    ) m(model_ad,deger)
    JOIN bi_tahmin_model mm ON mm.model_ad=m.model_ad AND mm.aktif
   WHERE m.deger IS NOT NULL AND m.deger >= 0
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- Canli uretici: TEK degisiklik uretim_gun ifadesinde, gerisi aynen
CREATE OR REPLACE FUNCTION bi_tahmin_canli_uret_ufuk(p_hedef date, p_ufuk_ay integer DEFAULT 1)
RETURNS TABLE(kosum_tipi text, satir_say integer) LANGUAGE plpgsql AS $fn$
DECLARE h date; u integer; ug integer; hk numeric;
BEGIN
  h  := date_trunc('month', p_hedef)::date;
  u  := p_ufuk_ay;  ug := u * 30;
  hk := bi_parametre_coz('bant_hedef_kapsama');
  DELETE FROM bi_tahmin bt
   WHERE bt.kosum IN ('canli','golge') AND bt.hedef_donem = h AND bt.ufuk_gun = ug;
  INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                         ufuk_gun,yontem,model_ad,tahmin_deger,alt_bant,ust_bant,kosum,varsayimlar)
  WITH s AS (SELECT * FROM bi_tahmin_sampiyon WHERE ufuk_gun = ug),
  lag AS (
    SELECT s.*,
           CASE WHEN s.nesne='adet' THEN m1.adet  ELSE m1.ciro  END l1,
           CASE WHEN s.nesne='adet' THEN m2.adet  ELSE m2.ciro  END l2,
           CASE WHEN s.nesne='adet' THEN m3.adet  ELSE m3.ciro  END l3,
           CASE WHEN s.nesne='adet' THEN m12.adet ELSE m12.ciro END l12,
           CASE WHEN s.nesne='adet' THEN m13.adet ELSE m13.ciro END l13,
           CASE WHEN s.nesne='adet' THEN m14.adet ELSE m14.ciro END l14,
           CASE WHEN s.nesne='adet' THEN m15.adet ELSE m15.ciro END l15
      FROM s
      LEFT JOIN mv_gerceklesen_aylik m1  ON m1.tid=s.tenant_id  AND m1.varlik_tipi=s.varlik_tipi
             AND m1.varlik_kodu=s.varlik_kodu  AND m1.donem =(h-(u||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik m2  ON m2.tid=s.tenant_id  AND m2.varlik_tipi=s.varlik_tipi
             AND m2.varlik_kodu=s.varlik_kodu  AND m2.donem =(h-((u+1)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik m3  ON m3.tid=s.tenant_id  AND m3.varlik_tipi=s.varlik_tipi
             AND m3.varlik_kodu=s.varlik_kodu  AND m3.donem =(h-((u+2)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik m12 ON m12.tid=s.tenant_id AND m12.varlik_tipi=s.varlik_tipi
             AND m12.varlik_kodu=s.varlik_kodu AND m12.donem=(h-interval '12 months')::date
      LEFT JOIN mv_gerceklesen_aylik m13 ON m13.tid=s.tenant_id AND m13.varlik_tipi=s.varlik_tipi
             AND m13.varlik_kodu=s.varlik_kodu AND m13.donem=(h-((12+u)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik m14 ON m14.tid=s.tenant_id AND m14.varlik_tipi=s.varlik_tipi
             AND m14.varlik_kodu=s.varlik_kodu AND m14.donem=(h-((13+u)||' months')::interval)::date
      LEFT JOIN mv_gerceklesen_aylik m15 ON m15.tid=s.tenant_id AND m15.varlik_tipi=s.varlik_tipi
             AND m15.varlik_kodu=s.varlik_kodu AND m15.donem=(h-((14+u)||' months')::interval)::date),
  cek AS (
    SELECT l.tenant_id,l.nesne,l.varlik_tipi,l.varlik_kodu,
           sum(w.agirlik*COALESCE(ka.fatura_tutar,0)) deger
      FROM lag l
      JOIN bi_tahsilat_cekirdek w ON w.tenant_id=l.tenant_id
       AND w.kohort_kesim=(SELECT max(kohort_kesim) FROM bi_tahsilat_cekirdek)
      LEFT JOIN v_kohort_kanon ka ON ka.tid=l.tenant_id
       AND ka.kohort_ay=(h - (GREATEST(w.gecikme_ay,u)||' months')::interval)::date
     WHERE u = 1 AND l.varlik_tipi='tahsilat' AND l.varlik_kodu='TOPLAM' AND l.nesne='ciro'
     GROUP BY 1,2,3,4),
  aday AS (
    SELECT l.*, c.deger cek,
           l.l1 AS a_naif, l.l12 AS a_mnaif,
           (COALESCE(l.l1,0)+COALESCE(l.l2,0)+COALESCE(l.l3,0))
             / NULLIF((l.l1 IS NOT NULL)::int+(l.l2 IS NOT NULL)::int+(l.l3 IS NOT NULL)::int,0) AS a_ma3,
           l.l12*(COALESCE(l.l1,0)+COALESCE(l.l2,0)+COALESCE(l.l3,0))
             / NULLIF(COALESCE(l.l13,0)+COALESCE(l.l14,0)+COALESCE(l.l15,0),0) AS a_mtrend
      FROM lag l LEFT JOIN cek c ON c.tenant_id=l.tenant_id AND c.nesne=l.nesne
           AND c.varlik_tipi=l.varlik_tipi AND c.varlik_kodu=l.varlik_kodu),
  tah AS (
    SELECT a.*, med.med, med.say,
           CASE a.model_ad
             WHEN 'naif'                    THEN a.a_naif
             WHEN 'mevsimsel_naif'          THEN a.a_mnaif
             WHEN 'hareketli_ort_3'         THEN a.a_ma3
             WHEN 'mevsimsel_trend'         THEN a.a_mtrend
             WHEN 'tahsilat_cekirdek_kanon' THEN a.cek
             WHEN 'birlesik_medyan'         THEN CASE WHEN med.say>=4 THEN med.med END
             ELSE NULL END AS deger
      FROM aday a
      LEFT JOIN LATERAL (
        SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY x) med, count(*) say
          FROM unnest(ARRAY[a.a_naif,a.a_mnaif,a.a_ma3,a.a_mtrend,a.cek]) x
         WHERE x IS NOT NULL AND x >= 0) med ON true)
  SELECT t.tenant_id,
         (h - ((u-1)||' months')::interval)::date - 1,      -- <<< TEK DEGISIKLIK
         t.nesne,t.varlik_tipi,t.varlik_kodu,h,ug,'taban',t.model_ad,
         t.deger, t.deger*(1+b.q_alt), t.deger*(1+b.q_ust),
         CASE WHEN COALESCE(k.yayinlanabilir,false) AND b.q_alt IS NOT NULL
              THEN 'canli' ELSE 'golge' END,
         jsonb_build_object('kapi',COALESCE(k.yayinlanabilir,false),
                            'bant_var',(b.q_alt IS NOT NULL),'aday_say',t.say,'ufuk_ay',u,
                            'medyan_mape',k.medyan_mape,'bant_kapsama',k.bant_kapsama_pct,
                            'bant_genislik',k.bant_genislik,'gozlem',k.n,'pencere',k.donem_say)
    FROM tah t
    LEFT JOIN bi_tahmin_bant_ayar b
      ON b.tenant_id=t.tenant_id AND b.nesne=t.nesne AND b.varlik_tipi=t.varlik_tipi
     AND b.varlik_kodu=t.varlik_kodu AND b.ufuk_gun=ug AND b.model_ad=t.model_ad
     AND b.hedef_kapsama = hk
    LEFT JOIN v_tahmin_yayin_kapisi k
      ON k.tenant_id=t.tenant_id AND k.nesne=t.nesne AND k.varlik_tipi=t.varlik_tipi
     AND k.varlik_kodu=t.varlik_kodu AND k.model_ad=t.model_ad AND k.ufuk_gun=ug
   WHERE t.deger IS NOT NULL AND t.deger >= 0;
  RETURN QUERY SELECT bt.kosum, count(*)::int FROM bi_tahmin bt
    WHERE bt.hedef_donem=h AND bt.ufuk_gun=ug AND bt.kosum IN ('canli','golge')
    GROUP BY bt.kosum;
END $fn$;
