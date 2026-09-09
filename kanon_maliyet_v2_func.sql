-- ============================================================================
-- KANON MALİYET V2 — akış maliyetini ANA fonksiyona göm.
-- metrik_marj_atom_uret: maliyet DIŞINDA her şey aynı (satış gruplaması + teşvik).
--   ESKİ maliyet: en son alış-AYININ ağırlıklı ort. (oynak, tek pahalı ay tüm satışa)
--   YENİ maliyet (akış): o ay satılan adet kadar, en son alım LOTLARININ adet-ağırlıklı
--     ort. (sınır lotu kısmi ağırlık). Sihirli N yok (N=satılan adet). Aykırıya dayanıklı.
-- Cost dışı: _sal (satış), _tm (teşvik marka), tesvik LATERAL, tüm kolonlar KORUNDU.
-- Çalıştırma:  cat kanon_maliyet_v2_func.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- Geri alma:   cat metrik_marj_atom_uret.BAK.sql | docker exec -i krb-assessment-postgres psql ...  (sonra rebuild)
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

CREATE OR REPLACE FUNCTION public.metrik_marj_atom_uret(p_tenant uuid, p_ay_geri integer DEFAULT 24)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE n int; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  DELETE FROM bi_marj_atom WHERE tenant_id=p_tenant AND ay >= m0 - make_interval(months=>p_ay_geri);

  CREATE TEMP TABLE _sal ON COMMIT DROP AS
    SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, max(marka) marka, max(ebat) ebat, max(kategori) kategori,
           max(substring(coalesce(jant_capi,'') from '[0-9]{2}')::int) jant,
           sum(miktar) adet, sum(satir_tutar) ciro
      FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND ebat IS NOT NULL AND miktar>0
        AND fatura_tarihi >= m0 - make_interval(months=>p_ay_geri) AND fatura_tarihi < m0 GROUP BY 1,2;
  CREATE INDEX ON _sal(kalem_kodu, ay);

  -- AKIŞ MALİYETİ: satılan adet kadar en son alım lotları, adet-ağırlıklı (sınır lotu kısmi)
  CREATE TEMP TABLE _cost ON COMMIT DROP AS
    WITH lots AS (
      SELECT s.kalem_kodu, s.ay, s.adet::numeric sold_qty, h.giris::numeric giris,
             (h.giris_tutari/NULLIF(h.giris,0))::numeric uc,
             sum(h.giris) OVER (PARTITION BY s.kalem_kodu, s.ay
                                ORDER BY h.belge_tarihi DESC, h.ctid DESC
                                ROWS UNBOUNDED PRECEDING) run
        FROM _sal s
        JOIN bi_stok_hareket h
          ON h.tenant_id=p_tenant AND h.kalem_kodu=s.kalem_kodu
         AND h.hareket_sinifi IN ('MAL_GIRISI','ACILIS')
         AND h.giris>0 AND h.giris_tutari>0
         AND h.belge_tarihi < s.ay + interval '1 month'
    ),
    used AS (
      SELECT kalem_kodu, ay, sold_qty, uc,
             greatest(0, least(giris, sold_qty-(run-giris)))::numeric uq
        FROM lots
    )
    SELECT kalem_kodu, ay,
           sum(uc*uq)/NULLIF(sum(uq),0) mc,
           round(100*sum(uq)/NULLIF(max(sold_qty),0)) kapsam
      FROM used WHERE uq>0 GROUP BY 1,2;
  CREATE INDEX ON _cost(kalem_kodu, ay);

  CREATE TEMP TABLE _tm ON COMMIT DROP AS
    SELECT DISTINCT upper(marka) marka FROM bi_tedarikci_tesvik WHERE tenant_id=p_tenant;

  INSERT INTO bi_marj_atom (tenant_id,kalem_kodu,ay,marka,ebat,kategori,adet,ciro,ort_fiyat,birim_maliyet,maliyet_kaynak,brut_kar,marj_pct,
                            tesvik_kesin_pct,tesvik_max_pct,kesin_net_kar,kesin_net_marj_pct,pot_net_marj_pct,tesvik_kaynak)
  SELECT p_tenant, sl.kalem_kodu, sl.ay, sl.marka, sl.ebat, sl.kategori, sl.adet, sl.ciro,
         round(sl.ciro/NULLIF(sl.adet,0)), round(c.mc),
         CASE WHEN c.kapsam >= 99 THEN 'donem' ELSE 'fallback' END,
         round(sl.ciro - sl.adet*c.mc), round(100*(sl.ciro - sl.adet*c.mc)/NULLIF(sl.ciro,0),1),
         tv.f_pct, tv.m_pct,
         round(sl.ciro - sl.adet*c.mc*(1-coalesce(tv.f_pct,0)/100)),
         round(100*(sl.ciro - sl.adet*c.mc*(1-coalesce(tv.f_pct,0)/100))/NULLIF(sl.ciro,0),1),
         round(100*(sl.ciro - sl.adet*c.mc*(1-coalesce(tv.m_pct,0)/100))/NULLIF(sl.ciro,0),1),
         CASE WHEN tv.f_pct IS NOT NULL THEN 'tesvik-'||extract(year FROM sl.ay)::int
              WHEN tm.marka IS NOT NULL THEN 'veri-yok'
              ELSE 'kapsam-disi' END
    FROM _sal sl
    JOIN _cost c ON c.kalem_kodu=sl.kalem_kodu AND c.ay=sl.ay
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
   WHERE c.mc IS NOT NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $function$;

-- rebuild (tek transaction; hata olursa DELETE de geri alınır)
SELECT metrik_marj_atom_uret(:T::uuid, 24) AS atom_satir;

-- DOĞRULA 1: aylık ciro-ağırlıklı marj (çöküş gitti mi?)
SELECT to_char(ay,'YYYY-MM') ay, round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj
FROM bi_marj_atom WHERE tenant_id=:T::uuid AND ay >= date_trunc('month',CURRENT_DATE)-interval '12 month'
GROUP BY ay ORDER BY ay;

-- DOĞRULA 2: Bridgestone (eski −20,7 → ~+7 beklenir)
SELECT kalem_kodu, round(birim_maliyet) mal, marj_pct, maliyet_kaynak
FROM bi_marj_atom WHERE tenant_id=:T::uuid AND ay='2026-07-01' AND marka='BRIDGESTONE'
ORDER BY ciro DESC LIMIT 6;

-- DOĞRULA 3: genel sağlık — kaç satır, negatif marj oranı
SELECT count(*) satir,
       round(100.0*count(*) FILTER (WHERE marj_pct<0)/NULLIF(count(*),0),1) negatif_pct,
       round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) genel_marj
FROM bi_marj_atom WHERE tenant_id=:T::uuid AND ay >= date_trunc('month',CURRENT_DATE)-interval '12 month';
