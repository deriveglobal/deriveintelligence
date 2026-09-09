INSERT INTO bi_tahmin_yayin_esik
  (tenant_id, nesne, min_gozlem, min_donem, max_medyan_mape, min_bant_kapsama, max_bant_kapsama)
SELECT t.tid, n.nesne, 12, 12, 25, 70, 95
  FROM bi_tenant_listesi() t CROSS JOIN (VALUES ('adet'),('ciro')) n(nesne)
 WHERE NOT EXISTS (SELECT 1 FROM bi_tahmin_yayin_esik e
                    WHERE e.tenant_id=t.tid AND e.nesne=n.nesne);

DO $g$
DECLARE eksik integer;
BEGIN
  SELECT count(*) INTO eksik
    FROM bi_tenant_listesi() t CROSS JOIN (VALUES ('adet'),('ciro')) n(nesne)
    LEFT JOIN bi_tahmin_yayin_esik e ON e.tenant_id=t.tid AND e.nesne=n.nesne
   WHERE e.tenant_id IS NULL;
  IF eksik > 0 THEN
    RAISE EXCEPTION 'esik satiri eksik (%), COALESCE kaldirilmadi', eksik;
  END IF;
END $g$;

CREATE OR REPLACE VIEW v_tahmin_yayin_kapisi AS
 WITH ham AS (
   SELECT i.tenant_id, i.nesne, i.varlik_tipi, i.varlik_kodu, i.sinif, i.ufuk_gun,
          i.yontem, i.model_ad, i.n, i.medyan_mape, i.ort_mape, i.bant_kapsama_pct,
          i.donem_say, i.bantli_n, i.bant_genislik,
          e.min_gozlem, e.min_donem, e.max_medyan_mape,
          e.min_bant_kapsama, e.max_bant_kapsama, r.kirilma_orani,
          (i.n >= e.min_gozlem
       AND i.donem_say >= e.min_donem
       AND i.bantli_n >= ceil(2::numeric / (1::numeric - bi_parametre_coz('bant_hedef_kapsama')))
       AND i.medyan_mape <= e.max_medyan_mape
       AND COALESCE(i.bant_kapsama_pct,0::numeric)   >= e.min_bant_kapsama
       AND COALESCE(i.bant_kapsama_pct,100::numeric) <= e.max_bant_kapsama
       AND COALESCE(i.bant_genislik,99::numeric) <= bi_parametre_coz('kapi_max_bant_genislik'))
          AS istatistik_gecti,
          (r.n_ilk >= 6 AND r.n_son >= 6 AND NOT COALESCE(r.kirildi, true)) AS rejim_gecti
     FROM v_tahmin_isabet i
     LEFT JOIN bi_tahmin_yayin_esik e ON e.tenant_id=i.tenant_id AND e.nesne=i.nesne
     LEFT JOIN v_tahmin_rejim r ON r.tenant_id=i.tenant_id AND r.varlik_tipi=i.varlik_tipi
                               AND r.varlik_kodu=i.varlik_kodu AND r.nesne=i.nesne
 ), sampiyon_ham AS (
   SELECT h_1.tenant_id,h_1.nesne,h_1.varlik_tipi,h_1.varlik_kodu,h_1.sinif,h_1.ufuk_gun,
          h_1.yontem,h_1.model_ad,h_1.n,h_1.medyan_mape,h_1.ort_mape,h_1.bant_kapsama_pct,
          h_1.donem_say,h_1.bantli_n,h_1.bant_genislik,h_1.min_gozlem,h_1.min_donem,
          h_1.max_medyan_mape,h_1.min_bant_kapsama,h_1.max_bant_kapsama,
          h_1.istatistik_gecti, h_1.rejim_gecti
     FROM ham h_1
     JOIN bi_tahmin_sampiyon s
       ON s.tenant_id=h_1.tenant_id AND s.nesne=h_1.nesne AND s.varlik_tipi=h_1.varlik_tipi
      AND s.varlik_kodu=h_1.varlik_kodu AND s.ufuk_gun=h_1.ufuk_gun AND s.model_ad=h_1.model_ad
 )
 SELECT h.tenant_id,h.nesne,h.varlik_tipi,h.varlik_kodu,h.sinif,h.ufuk_gun,h.yontem,h.model_ad,
        h.n,h.medyan_mape,h.ort_mape,h.bant_kapsama_pct,h.donem_say,h.bantli_n,h.bant_genislik,
        h.min_gozlem,h.min_donem,h.max_medyan_mape,h.min_bant_kapsama,h.max_bant_kapsama,
        h.istatistik_gecti,
        CASE WHEN h.nesne='ciro' AND COALESCE(k.eslik_gerekli,true)
             THEN COALESCE(a.istatistik_gecti,false) ELSE true END AS eslik_gecti,
        COALESCE(k.yuzeyde_gosterilir,true) AS yuzeyde,
        COALESCE(eb.istatistik_gecti,false) AS ebeveyn_acik,
        COALESCE(h.istatistik_gecti,false)
        AND (CASE WHEN h.nesne='ciro' AND COALESCE(k.eslik_gerekli,true)
                  THEN COALESCE(a.istatistik_gecti,false) ELSE true END)
        AND COALESCE(k.yuzeyde_gosterilir,true)
        AND NOT COALESCE(eb.istatistik_gecti,false)
        AND h.rejim_gecti
        AND (CASE WHEN h.nesne='ciro' AND COALESCE(k.eslik_gerekli,true)
                  THEN COALESCE(a.rejim_gecti,false) ELSE true END)
          AS yayinlanabilir,
        h.rejim_gecti, h.kirilma_orani
   FROM ham h
   LEFT JOIN bi_tahmin_nesne_kural k ON k.varlik_tipi=h.varlik_tipi
   LEFT JOIN ham a ON a.tenant_id=h.tenant_id AND a.varlik_tipi=h.varlik_tipi
        AND a.varlik_kodu=h.varlik_kodu AND a.sinif=h.sinif AND a.ufuk_gun=h.ufuk_gun
        AND a.yontem=h.yontem AND a.model_ad=h.model_ad AND a.nesne='adet'
   LEFT JOIN v_tahmin_seviye sv ON sv.tid=h.tenant_id AND sv.alt_tip=h.varlik_tipi
        AND sv.alt_kod=h.varlik_kodu
   LEFT JOIN sampiyon_ham eb ON eb.tenant_id=h.tenant_id AND eb.nesne=h.nesne
        AND eb.varlik_tipi=sv.ust_tip AND eb.varlik_kodu=sv.ust_kod AND eb.ufuk_gun=h.ufuk_gun;
