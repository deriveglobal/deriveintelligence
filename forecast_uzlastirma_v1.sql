-- Hiyerarsiye tahsilat kolunu ekle
CREATE OR REPLACE VIEW v_varlik_hiyerarsi AS
SELECT DISTINCT tenant_id::uuid tid,'kategori'::text alt_tip, kategori::text alt_kod,
       'segment'::text ust_tip, kategori_segment(kategori, tenant_id::uuid)::text ust_kod
  FROM bi_satis_faturalari WHERE COALESCE(kategori,'')<>''
UNION
SELECT DISTINCT tenant_id::uuid,'segment', kategori_segment(kategori, tenant_id::uuid)::text,
       'TOPLAM','TOPLAM' FROM bi_satis_faturalari WHERE COALESCE(kategori,'')<>''
UNION
SELECT DISTINCT tid,'tahsilat_grup', varlik_kodu,'tahsilat','TOPLAM'
  FROM mv_gerceklesen_aylik WHERE varlik_tipi='tahsilat_grup';

INSERT INTO bi_tahmin_model (model_ad,aile,aciklama,isinma_ay,yapisal_lag) VALUES
 ('ima_edilen_toplam','uzlastirma',
  'Cocuk hucrelerin sampiyon tahminlerinin toplami — ebeveyn tahmini olarak yarisir',12,12)
ON CONFLICT DO NOTHING;

-- Ima edilen toplam: cocuklarin sampiyon tahminlerinin toplami
INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                       ufuk_gun,yontem,model_ad,tahmin_deger,kosum,varsayimlar)
SELECT t.tenant_id, min(t.uretim_gun), t.nesne, 'tahsilat','TOPLAM', t.hedef_donem, t.ufuk_gun,
       'taban','ima_edilen_toplam', sum(t.tahmin_deger),'backtest',
       jsonb_build_object('cocuk_say',count(*),'kaynak','tahsilat_grup sampiyonlari')
  FROM bi_tahmin t
  JOIN bi_tahmin_sampiyon s
    ON s.tenant_id=t.tenant_id AND s.nesne=t.nesne AND s.varlik_tipi=t.varlik_tipi
   AND s.varlik_kodu=t.varlik_kodu AND s.ufuk_gun=t.ufuk_gun AND s.model_ad=t.model_ad
 WHERE t.kosum='backtest' AND t.varlik_tipi='tahsilat_grup'
 GROUP BY t.tenant_id,t.nesne,t.hedef_donem,t.ufuk_gun
HAVING count(*) >= 5
ON CONFLICT DO NOTHING;
