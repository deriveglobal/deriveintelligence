CREATE OR REPLACE FUNCTION bi_tahmin_sampiyon_sec_kararli(
  p_min_pencere integer DEFAULT 3, p_max_skor numeric DEFAULT 60)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer; mj numeric;
BEGIN
  mj := bi_parametre_coz('sampiyon_marj');

  INSERT INTO bi_tahmin_sampiyon
    (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun,model_ad,medyan_mape,n,donem_say,
     kararli_skor,oynaklik,pencere_say,olcut)
  WITH k AS (
    SELECT kk.*, COALESCE(g.istatistik_gecti,false) gecti
      FROM v_tahmin_kararlilik kk
      LEFT JOIN v_tahmin_yayin_kapisi g
        ON g.tenant_id=kk.tenant_id AND g.nesne=kk.nesne AND g.varlik_tipi=kk.varlik_tipi
       AND g.varlik_kodu=kk.varlik_kodu AND g.ufuk_gun=kk.ufuk_gun AND g.model_ad=kk.model_ad
     WHERE kk.pencere_say >= p_min_pencere AND kk.kararli_skor <= p_max_skor),
  bir AS (SELECT * FROM k WHERE model_ad='birlesik_medyan'),
  tek AS (SELECT DISTINCT ON (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun) *
            FROM k WHERE model_ad<>'birlesik_medyan'
           ORDER BY tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun, gecti DESC, kararli_skor),
  sec AS (
    SELECT COALESCE(t.tenant_id,b.tenant_id) tid, COALESCE(t.nesne,b.nesne) nesne,
           COALESCE(t.varlik_tipi,b.varlik_tipi) vt, COALESCE(t.varlik_kodu,b.varlik_kodu) vk,
           COALESCE(t.ufuk_gun,b.ufuk_gun) uf,
           (b.model_ad IS NOT NULL AND
            (t.model_ad IS NULL
             OR (b.gecti AND NOT t.gecti)
             OR (b.gecti = t.gecti AND t.kararli_skor >= b.kararli_skor*(1-mj)))) birlesim_mi,
           b.model_ad b_ad, b.ort_mape b_mape, b.kararli_skor b_skor, b.oynaklik b_oyn,
           b.pencere_say b_pen, b.gecti b_gecti,
           t.model_ad t_ad, t.ort_mape t_mape, t.kararli_skor t_skor, t.oynaklik t_oyn,
           t.pencere_say t_pen, t.gecti t_gecti
      FROM tek t FULL OUTER JOIN bir b
        ON b.tenant_id=t.tenant_id AND b.nesne=t.nesne AND b.varlik_tipi=t.varlik_tipi
       AND b.varlik_kodu=t.varlik_kodu AND b.ufuk_gun=t.ufuk_gun)
  SELECT tid,nesne,vt,vk,uf,
         CASE WHEN birlesim_mi THEN b_ad ELSE t_ad END,
         CASE WHEN birlesim_mi THEN b_mape ELSE t_mape END, 0, 0,
         CASE WHEN birlesim_mi THEN b_skor ELSE t_skor END,
         CASE WHEN birlesim_mi THEN b_oyn ELSE t_oyn END,
         CASE WHEN birlesim_mi THEN b_pen ELSE t_pen END,
         CASE WHEN birlesim_mi THEN
                CASE WHEN b_gecti THEN 'birlesim+kapi' ELSE 'birlesim(golge)' END
              ELSE CASE WHEN t_gecti THEN 'tek+kapi' ELSE 'tek(golge)' END END
    FROM sec
   WHERE COALESCE(CASE WHEN birlesim_mi THEN b_ad ELSE t_ad END,'') <> ''
  ON CONFLICT (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun) DO UPDATE SET
     onceki_model=bi_tahmin_sampiyon.model_ad, onceki_mape=bi_tahmin_sampiyon.medyan_mape,
     model_ad=EXCLUDED.model_ad, medyan_mape=EXCLUDED.medyan_mape,
     kararli_skor=EXCLUDED.kararli_skor, oynaklik=EXCLUDED.oynaklik,
     pencere_say=EXCLUDED.pencere_say, olcut=EXCLUDED.olcut, secildi_at=now();
  GET DIAGNOSTICS v=ROW_COUNT; RETURN v;
END $fn$;
