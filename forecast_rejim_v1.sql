-- ONUNCU KAPI SARTI: rejim kirilmasi.
-- Bir hucrenin olcum penceresi icinde seviye kaymasi bandin yari-genisligini
-- asiyorsa, o pencerede olculen hata bugunku rejimi temsil etmez -> yayin yok.
-- Esik uydurma degil: bant noktanin etrafinda +-yari-genislik uzanir; bundan
-- buyuk bir seviye kaymasini bant tanimi geregi kapsayamaz.
CREATE OR REPLACE VIEW v_tahmin_rejim AS
WITH kapali AS (
  SELECT m.tid, m.varlik_tipi, m.varlik_kodu, m.donem, m.adet, m.ciro
    FROM mv_gerceklesen_aylik m
   WHERE m.donem < date_trunc('month', CURRENT_DATE)::date),
sinir AS (SELECT k.tid, max(k.donem) AS son FROM kapali k GROUP BY 1),
p AS (
  SELECT k.*, (s.son - interval '11 months')::date AS orta
    FROM kapali k JOIN sinir s ON s.tid = k.tid
   WHERE k.donem >= (s.son - interval '23 months')::date),
u AS (
  SELECT p.tid, p.varlik_tipi, p.varlik_kodu, n.nesne,
         CASE WHEN n.nesne='adet' THEN p.adet ELSE p.ciro END AS v,
         (p.donem >= p.orta) AS son_yari
    FROM p CROSS JOIN (VALUES ('adet'),('ciro')) n(nesne))
SELECT u.tid AS tenant_id, u.varlik_tipi, u.varlik_kodu, u.nesne,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY u.v)
         FILTER (WHERE NOT u.son_yari) AS ilk_yari,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY u.v)
         FILTER (WHERE u.son_yari)     AS son_yari,
       count(*) FILTER (WHERE NOT u.son_yari) AS n_ilk,
       count(*) FILTER (WHERE u.son_yari)     AS n_son,
       CASE WHEN percentile_cont(0.5) WITHIN GROUP (ORDER BY u.v)
                   FILTER (WHERE NOT u.son_yari) > 0
            THEN abs(percentile_cont(0.5) WITHIN GROUP (ORDER BY u.v) FILTER (WHERE u.son_yari)
                   - percentile_cont(0.5) WITHIN GROUP (ORDER BY u.v) FILTER (WHERE NOT u.son_yari))
               / percentile_cont(0.5) WITHIN GROUP (ORDER BY u.v) FILTER (WHERE NOT u.son_yari)
       END AS kirilma_orani
  FROM u WHERE u.v IS NOT NULL
 GROUP BY 1,2,3,4;

CREATE OR REPLACE VIEW v_tahmin_yayin_kapisi AS
 WITH ham AS (
   SELECT i.tenant_id, i.nesne, i.varlik_tipi, i.varlik_kodu, i.sinif, i.ufuk_gun,
          i.yontem, i.model_ad, i.n, i.medyan_mape, i.ort_mape, i.bant_kapsama_pct,
          i.donem_say, i.bantli_n, i.bant_genislik,
          e.min_gozlem, e.min_donem, e.max_medyan_mape,
          e.min_bant_kapsama, e.max_bant_kapsama,
          r.kirilma_orani, r.n_ilk, r.n_son,
          -- bantli_n esigi artik sabit degil, kapsama hedefinden turetiliyor:
          -- iki tarafli %C bant, (1+C)/2 kuantilini okur; bu kuantilin var olmasi
          -- icin gereken en az gozlem = 2/(1-C).  C=0,80 -> 10.
          (i.n >= COALESCE(e.min_gozlem,12)
       AND i.donem_say >= COALESCE(e.min_donem,12)
       AND i.bantli_n >= ceil(2::numeric / (1::numeric - bi_parametre_coz('bant_hedef_kapsama')))
       AND i.medyan_mape <= COALESCE(e.max_medyan_mape,25::numeric)
       AND COALESCE(i.bant_kapsama_pct,0::numeric)   >= COALESCE(e.min_bant_kapsama,70::numeric)
       AND COALESCE(i.bant_kapsama_pct,100::numeric) <= COALESCE(e.max_bant_kapsama,95::numeric)
       AND COALESCE(i.bant_genislik,99::numeric) <= bi_parametre_coz('kapi_max_bant_genislik'))
          AS istatistik_gecti,
          -- olcemiyorsak gecmis sayilmaz: iki yarida da yeterli gozlem sart
          (r.n_ilk >= 6 AND r.n_son >= 6
       AND COALESCE(r.kirilma_orani, 9) <= COALESCE(i.bant_genislik, 0::numeric)/2)
          AS rejim_gecti
     FROM v_tahmin_isabet i
     LEFT JOIN bi_tahmin_yayin_esik e
       ON e.tenant_id=i.tenant_id AND e.nesne=i.nesne
     LEFT JOIN v_tahmin_rejim r
       ON r.tenant_id=i.tenant_id AND r.varlik_tipi=i.varlik_tipi
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
        h.istatistik_gecti
        AND (CASE WHEN h.nesne='ciro' AND COALESCE(k.eslik_gerekli,true)
                  THEN COALESCE(a.istatistik_gecti,false) ELSE true END)
        AND COALESCE(k.yuzeyde_gosterilir,true)
        AND NOT COALESCE(eb.istatistik_gecti,false)
        AND h.rejim_gecti
        AND (CASE WHEN h.nesne='ciro' AND COALESCE(k.eslik_gerekli,true)
                  THEN COALESCE(a.rejim_gecti,false) ELSE true END)
          AS yayinlanabilir,
        h.rejim_gecti,
        h.kirilma_orani
   FROM ham h
   LEFT JOIN bi_tahmin_nesne_kural k ON k.varlik_tipi=h.varlik_tipi
   LEFT JOIN ham a ON a.tenant_id=h.tenant_id AND a.varlik_tipi=h.varlik_tipi
        AND a.varlik_kodu=h.varlik_kodu AND a.sinif=h.sinif AND a.ufuk_gun=h.ufuk_gun
        AND a.yontem=h.yontem AND a.model_ad=h.model_ad AND a.nesne='adet'
   LEFT JOIN v_tahmin_seviye sv ON sv.tid=h.tenant_id AND sv.alt_tip=h.varlik_tipi
        AND sv.alt_kod=h.varlik_kodu
   LEFT JOIN sampiyon_ham eb ON eb.tenant_id=h.tenant_id AND eb.nesne=h.nesne
        AND eb.varlik_tipi=sv.ust_tip AND eb.varlik_kodu=sv.ust_kod AND eb.ufuk_gun=h.ufuk_gun;
