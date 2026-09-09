SET lock_timeout='5s';

-- Kapi durum degisiklikleri: acilma/kapanma da bir olaydir
CREATE TABLE IF NOT EXISTS bi_kapi_gecmisi (
  id bigserial PRIMARY KEY, tenant_id uuid, nesne text, varlik_tipi text, varlik_kodu text,
  model_ad text, eski_durum boolean, yeni_durum boolean,
  medyan_mape numeric, bant_kapsama numeric, gerekce text,
  degisti_at timestamptz DEFAULT now());

-- CANLI/GOLGE URETIM: sampiyonu olan her hucre icin bir sonraki ay
CREATE OR REPLACE FUNCTION bi_tahmin_canli_uret(p_hedef date DEFAULT NULL)
RETURNS TABLE(kosum text, satir integer) LANGUAGE plpgsql AS $fn$
DECLARE h date; v integer;
BEGIN
  h := COALESCE(p_hedef, date_trunc('month',CURRENT_DATE)::date);

  DELETE FROM bi_tahmin WHERE kosum IN ('canli','golge') AND hedef_donem = h;

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
  cek AS (   -- kanon cekirdek modeli icin konvolusyon
    SELECT l.tenant_id,l.nesne,l.varlik_tipi,l.varlik_kodu,l.ufuk_gun,
           sum(w.agirlik*COALESCE(ka.fatura_tutar,0)) deger
      FROM lag l
      JOIN bi_tahsilat_cekirdek w ON w.tenant_id=l.tenant_id
       AND w.kohort_kesim=(SELECT max(kohort_kesim) FROM bi_tahsilat_cekirdek)
      LEFT JOIN v_kohort_kanon ka ON ka.tid=l.tenant_id
       AND ka.kohort_ay=(h - (GREATEST(w.gecikme_ay,1)||' months')::interval)::date
     WHERE l.model_ad='tahsilat_cekirdek_kanon'
     GROUP BY 1,2,3,4,5),
  tah AS (
    SELECT l.*, CASE l.model_ad
      WHEN 'naif'            THEN l.l1
      WHEN 'mevsimsel_naif'  THEN l.l12
      WHEN 'hareketli_ort_3' THEN (COALESCE(l.l1,0)+COALESCE(l.l2,0)+COALESCE(l.l3,0))
            / NULLIF((l.l1 IS NOT NULL)::int+(l.l2 IS NOT NULL)::int+(l.l3 IS NOT NULL)::int,0)
      WHEN 'mevsimsel_trend' THEN l.l12*(COALESCE(l.l1,0)+COALESCE(l.l2,0)+COALESCE(l.l3,0))
            / NULLIF(COALESCE(l.l13,0)+COALESCE(l.l14,0)+COALESCE(l.l15,0),0)
      WHEN 'tahsilat_cekirdek_kanon' THEN c.deger
      ELSE NULL END AS deger
      FROM lag l LEFT JOIN cek c ON c.tenant_id=l.tenant_id AND c.nesne=l.nesne
           AND c.varlik_tipi=l.varlik_tipi AND c.varlik_kodu=l.varlik_kodu)
  SELECT t.tenant_id,(h-1),t.nesne,t.varlik_tipi,t.varlik_kodu,h,30,'taban',t.model_ad,
         t.deger,
         t.deger*(1+b.q_alt), t.deger*(1+b.q_ust),
         CASE WHEN COALESCE(k.yayinlanabilir,false) THEN 'canli' ELSE 'golge' END,
         jsonb_build_object('kapi',COALESCE(k.yayinlanabilir,false),
                            'medyan_mape',k.medyan_mape,'bant_kapsama',k.bant_kapsama_pct,
                            'gozlem',k.n,'pencere',k.donem_say)
    FROM tah t
    LEFT JOIN bi_tahmin_bant_ayar b
      ON b.tenant_id=t.tenant_id AND b.nesne=t.nesne AND b.varlik_tipi=t.varlik_tipi
     AND b.varlik_kodu=t.varlik_kodu AND b.ufuk_gun=t.ufuk_gun AND b.model_ad=t.model_ad
     AND b.hedef_kapsama=(SELECT max(hedef_kapsama) FROM bi_tahmin_bant_ayar)
    LEFT JOIN v_tahmin_yayin_kapisi k
      ON k.tenant_id=t.tenant_id AND k.nesne=t.nesne AND k.varlik_tipi=t.varlik_tipi
     AND k.model_ad=t.model_ad AND k.ufuk_gun=t.ufuk_gun
   WHERE t.deger IS NOT NULL AND t.deger >= 0;

  RETURN QUERY SELECT bt.kosum, count(*)::int FROM bi_tahmin bt
    WHERE bt.hedef_donem=h AND bt.kosum IN ('canli','golge') GROUP BY 1;
END $fn$;

-- GUNLUK DONGU
CREATE OR REPLACE FUNCTION bi_forecast_gunluk()
RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE r text;
BEGIN
  REFRESH MATERIALIZED VIEW mv_gerceklesen_aylik;
  PERFORM bi_tahmin_degerlendir();
  PERFORM bi_isinma_turet();
  PERFORM bi_tahmin_sampiyon_sec_kararli();
  PERFORM bi_tahmin_canli_uret();
  SELECT string_agg(x.kosum||'='||x.n, ' ') INTO r
    FROM (SELECT kosum, count(*) n FROM bi_tahmin
           WHERE hedef_donem=date_trunc('month',CURRENT_DATE)::date
             AND kosum IN ('canli','golge') GROUP BY 1) x;
  RETURN COALESCE(r,'uretim yok');
END $fn$;

-- YUZEY: modulun bugun soyledigi + guven kunyesi
CREATE OR REPLACE VIEW v_tahmin_yayin AS
SELECT t.tenant_id, t.hedef_donem, t.varlik_tipi, t.varlik_kodu, t.nesne, t.model_ad,
       round(t.tahmin_deger,0) tahmin, round(t.alt_bant,0) alt, round(t.ust_bant,0) ust,
       t.kosum,
       (t.varsayimlar->>'medyan_mape')::numeric gecmis_hata_pct,
       (t.varsayimlar->>'bant_kapsama')::numeric bant_tutma_pct,
       (t.varsayimlar->>'pencere')::int kac_donem_olculdu
  FROM bi_tahmin t
 WHERE t.kosum IN ('canli','golge');
