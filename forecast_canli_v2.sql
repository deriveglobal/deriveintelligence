CREATE OR REPLACE FUNCTION bi_tahmin_canli_uret(p_hedef date DEFAULT NULL)
RETURNS TABLE(kosum_tipi text, satir_say integer) LANGUAGE plpgsql AS $fn$
DECLARE h date; hk numeric;
BEGIN
  h  := COALESCE(p_hedef, date_trunc('month',CURRENT_DATE)::date);
  hk := bi_parametre_coz('bant_hedef_kapsama');
  DELETE FROM bi_tahmin bt WHERE bt.kosum IN ('canli','golge') AND bt.hedef_donem = h;

  INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                         ufuk_gun,yontem,model_ad,tahmin_deger,alt_bant,ust_bant,kosum,varsayimlar)
  WITH s AS (SELECT * FROM bi_tahmin_sampiyon),
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
             AND m1.varlik_kodu=s.varlik_kodu  AND m1.donem =(h-interval '1 month')::date
      LEFT JOIN mv_gerceklesen_aylik m2  ON m2.tid=s.tenant_id  AND m2.varlik_tipi=s.varlik_tipi
             AND m2.varlik_kodu=s.varlik_kodu  AND m2.donem =(h-interval '2 months')::date
      LEFT JOIN mv_gerceklesen_aylik m3  ON m3.tid=s.tenant_id  AND m3.varlik_tipi=s.varlik_tipi
             AND m3.varlik_kodu=s.varlik_kodu  AND m3.donem =(h-interval '3 months')::date
      LEFT JOIN mv_gerceklesen_aylik m12 ON m12.tid=s.tenant_id AND m12.varlik_tipi=s.varlik_tipi
             AND m12.varlik_kodu=s.varlik_kodu AND m12.donem=(h-interval '12 months')::date
      LEFT JOIN mv_gerceklesen_aylik m13 ON m13.tid=s.tenant_id AND m13.varlik_tipi=s.varlik_tipi
             AND m13.varlik_kodu=s.varlik_kodu AND m13.donem=(h-interval '13 months')::date
      LEFT JOIN mv_gerceklesen_aylik m14 ON m14.tid=s.tenant_id AND m14.varlik_tipi=s.varlik_tipi
             AND m14.varlik_kodu=s.varlik_kodu AND m14.donem=(h-interval '14 months')::date
      LEFT JOIN mv_gerceklesen_aylik m15 ON m15.tid=s.tenant_id AND m15.varlik_tipi=s.varlik_tipi
             AND m15.varlik_kodu=s.varlik_kodu AND m15.donem=(h-interval '15 months')::date),
  cek AS (
    SELECT l.tenant_id,l.nesne,l.varlik_tipi,l.varlik_kodu,l.ufuk_gun,
           sum(w.agirlik*COALESCE(ka.fatura_tutar,0)) deger
      FROM lag l
      JOIN bi_tahsilat_cekirdek w ON w.tenant_id=l.tenant_id
       AND w.kohort_kesim=(SELECT max(kohort_kesim) FROM bi_tahsilat_cekirdek)
      LEFT JOIN v_kohort_kanon ka ON ka.tid=l.tenant_id
       AND ka.kohort_ay=(h - (GREATEST(w.gecikme_ay,1)||' months')::interval)::date
     WHERE l.varlik_tipi='tahsilat' AND l.varlik_kodu='TOPLAM' AND l.nesne='ciro'
     GROUP BY 1,2,3,4,5),
  aday AS (
    SELECT l.*, c.deger cek,
           l.l1 AS a_naif,
           l.l12 AS a_mnaif,
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
  SELECT t.tenant_id,(h-1),t.nesne,t.varlik_tipi,t.varlik_kodu,h,30,'taban',t.model_ad,
         t.deger, t.deger*(1+b.q_alt), t.deger*(1+b.q_ust),
         CASE WHEN COALESCE(k.yayinlanabilir,false) AND b.q_alt IS NOT NULL
              THEN 'canli' ELSE 'golge' END,
         jsonb_build_object('kapi',COALESCE(k.yayinlanabilir,false),
                            'bant_var',(b.q_alt IS NOT NULL),'aday_say',t.say,
                            'medyan_mape',k.medyan_mape,'bant_kapsama',k.bant_kapsama_pct,
                            'bant_genislik',k.bant_genislik,'gozlem',k.n,'pencere',k.donem_say)
    FROM tah t
    LEFT JOIN bi_tahmin_bant_ayar b
      ON b.tenant_id=t.tenant_id AND b.nesne=t.nesne AND b.varlik_tipi=t.varlik_tipi
     AND b.varlik_kodu=t.varlik_kodu AND b.ufuk_gun=t.ufuk_gun AND b.model_ad=t.model_ad
     AND b.hedef_kapsama = hk
    LEFT JOIN v_tahmin_yayin_kapisi k
      ON k.tenant_id=t.tenant_id AND k.nesne=t.nesne AND k.varlik_tipi=t.varlik_tipi
     AND k.varlik_kodu=t.varlik_kodu AND k.model_ad=t.model_ad AND k.ufuk_gun=t.ufuk_gun
   WHERE t.deger IS NOT NULL AND t.deger >= 0;

  RETURN QUERY SELECT bt.kosum, count(*)::int FROM bi_tahmin bt
    WHERE bt.hedef_donem=h AND bt.kosum IN ('canli','golge') GROUP BY bt.kosum;
END $fn$;
