CREATE OR REPLACE FUNCTION public.metrik_marj_atom_uret(p_tenant uuid, p_ay_geri integer DEFAULT 24)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE n int; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  DELETE FROM bi_marj_atom WHERE tenant_id=p_tenant AND ay >= m0 - make_interval(months=>p_ay_geri);

  CREATE TEMP TABLE _pur ON COMMIT DROP AS
    SELECT kalem_kodu, date_trunc('month',belge_tarihi)::date ay,
           sum(giris_tutari)/NULLIF(sum(giris),0) mc
      FROM bi_stok_hareket
     WHERE tenant_id=p_tenant AND giris>=1 AND giris_tutari>0
       AND hareket_sinifi IN ('MAL_GIRISI','ACILIS')
     GROUP BY 1,2;
  CREATE INDEX ON _pur(kalem_kodu, ay DESC);

  CREATE TEMP TABLE _sal ON COMMIT DROP AS
    SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, max(marka) marka, max(ebat) ebat, max(kategori) kategori,
           max(substring(coalesce(jant_capi,'') from '[0-9]{2}')::int) jant,
           sum(miktar) adet, sum(satir_tutar) ciro
      FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND ebat IS NOT NULL AND miktar>0
        AND fatura_tarihi >= m0 - make_interval(months=>p_ay_geri) AND fatura_tarihi < m0 GROUP BY 1,2;
  CREATE INDEX ON _sal(kalem_kodu, ay);

  CREATE TEMP TABLE _tm ON COMMIT DROP AS
    SELECT DISTINCT upper(marka) marka FROM bi_tedarikci_tesvik WHERE tenant_id=p_tenant;

  INSERT INTO bi_marj_atom (tenant_id,kalem_kodu,ay,marka,ebat,kategori,adet,ciro,ort_fiyat,birim_maliyet,maliyet_kaynak,brut_kar,marj_pct,
                            tesvik_kesin_pct,tesvik_max_pct,kesin_net_kar,kesin_net_marj_pct,pot_net_marj_pct,tesvik_kaynak)
  SELECT p_tenant, sl.kalem_kodu, sl.ay, sl.marka, sl.ebat, sl.kategori, sl.adet, sl.ciro,
         round(sl.ciro/NULLIF(sl.adet,0)), round(pm.mc),
         CASE WHEN pm.ay >= sl.ay - interval '6 month' THEN 'donem' ELSE 'fallback' END,
         round(sl.ciro - sl.adet*pm.mc), round(100*(sl.ciro - sl.adet*pm.mc)/NULLIF(sl.ciro,0),1),
         tv.f_pct, tv.m_pct,
         round(sl.ciro - sl.adet*pm.mc*(1-coalesce(tv.f_pct,0)/100)),
         round(100*(sl.ciro - sl.adet*pm.mc*(1-coalesce(tv.f_pct,0)/100))/NULLIF(sl.ciro,0),1),
         round(100*(sl.ciro - sl.adet*pm.mc*(1-coalesce(tv.m_pct,0)/100))/NULLIF(sl.ciro,0),1),
         CASE WHEN tv.f_pct IS NOT NULL THEN 'tesvik-'||extract(year FROM sl.ay)::int
              WHEN tm.marka IS NOT NULL THEN 'veri-yok'
              ELSE 'kapsam-disi' END
    FROM _sal sl
    JOIN LATERAL (SELECT p.mc, p.ay FROM _pur p
                   WHERE p.kalem_kodu=sl.kalem_kodu AND p.ay<=sl.ay
                   ORDER BY p.ay DESC LIMIT 1) pm ON true
    LEFT JOIN _tm tm ON tm.marka=upper(sl.marka)
    LEFT JOIN bi_tesvik_segment_map sm ON sm.tenant_id=p_tenant AND sm.kategori=sl.kategori
    LEFT JOIN LATERAL (
      SELECT t.fatura_alti_pct f_pct, t.max_toplam_pct m_pct
        FROM bi_tedarikci_tesvik t
       WHERE t.tenant_id=p_tenant AND upper(t.marka)=upper(sl.marka)
         AND t.yil = extract(year FROM sl.ay)::int
         AND t.segment = sm.segment
         AND t.sezon = sm.sezon
       ORDER BY (t.kanal = CASE WHEN coalesce(sl.jant,0)>=17 THEN 'toptan' ELSE 'perakende' END) DESC,
                t.guncelleme_tarihi DESC
       LIMIT 1) tv ON true
   WHERE pm.mc IS NOT NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $function$

