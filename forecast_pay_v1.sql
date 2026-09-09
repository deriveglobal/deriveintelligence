INSERT INTO bi_tahmin_model (model_ad,aile,aciklama,isinma_ay,yapisal_lag) VALUES
 ('pay_bazli','uzlastirma',
  'Grup tahmini = ebeveyn sampiyon tahmini x grubun onceki ay payi — tanim geregi tutarli',12,12)
ON CONFLICT DO NOTHING;

INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                       ufuk_gun,yontem,model_ad,tahmin_deger,kosum,varsayimlar)
WITH ebeveyn AS (
  SELECT t.tenant_id,t.nesne,t.hedef_donem,t.ufuk_gun,t.uretim_gun,t.tahmin_deger p_deger
    FROM bi_tahmin t
    JOIN bi_tahmin_sampiyon s
      ON s.tenant_id=t.tenant_id AND s.nesne=t.nesne AND s.varlik_tipi=t.varlik_tipi
     AND s.varlik_kodu=t.varlik_kodu AND s.ufuk_gun=t.ufuk_gun AND s.model_ad=t.model_ad
   WHERE t.kosum='backtest' AND t.varlik_tipi='tahsilat' AND t.varlik_kodu='TOPLAM'),
pay AS (
  SELECT g.tid, g.varlik_kodu, g.donem, n.nesne,
         (CASE WHEN n.nesne='adet' THEN g.adet ELSE g.ciro END)
         / NULLIF(CASE WHEN n.nesne='adet' THEN tot.adet ELSE tot.ciro END,0) AS oran
    FROM mv_gerceklesen_aylik g
    JOIN mv_gerceklesen_aylik tot ON tot.tid=g.tid AND tot.varlik_tipi='tahsilat'
     AND tot.varlik_kodu='TOPLAM' AND tot.donem=g.donem
    CROSS JOIN (VALUES ('adet'),('ciro')) n(nesne)
   WHERE g.varlik_tipi='tahsilat_grup')
SELECT e.tenant_id, e.uretim_gun, e.nesne, 'tahsilat_grup', p.varlik_kodu, e.hedef_donem,
       e.ufuk_gun, 'taban','pay_bazli', e.p_deger * p.oran, 'backtest',
       jsonb_build_object('pay',round(p.oran::numeric,4),'pay_ayi',p.donem)
  FROM ebeveyn e
  JOIN pay p ON p.tid=e.tenant_id AND p.nesne=e.nesne
            AND p.donem = (e.hedef_donem - interval '1 month')::date
 WHERE p.oran > 0
ON CONFLICT DO NOTHING;
