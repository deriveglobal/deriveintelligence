CREATE OR REPLACE VIEW v_tahmin_atif AS
WITH e AS (
  SELECT t.id, t.tenant_id, t.nesne, t.varlik_tipi, t.varlik_kodu, t.ufuk_gun, t.model_ad,
         t.hedef_donem, t.tahmin_deger, s.gerceklesen, s.mutlak_yuzde_hata,
         sign(s.gerceklesen - t.tahmin_deger) yon,
         (s.gerceklesen - t.tahmin_deger)/NULLIF(t.tahmin_deger,0) goreli
    FROM bi_tahmin t JOIN bi_tahmin_sonuc s ON s.tahmin_id=t.id
   WHERE t.kosum='backtest' AND t.tahmin_deger>0 AND s.gerceklesen IS NOT NULL),
-- (a) SAPMA MI GURULTU MU: son 6 hatanin isaret tutarliligi
isaret AS (
  SELECT e.*,
         avg(CASE WHEN yon>0 THEN 1.0 ELSE 0.0 END) OVER (
           PARTITION BY tenant_id,nesne,varlik_tipi,varlik_kodu,model_ad
           ORDER BY hedef_donem ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) yukari_pay,
         count(*) OVER (
           PARTITION BY tenant_id,nesne,varlik_tipi,varlik_kodu,model_ad
           ORDER BY hedef_donem ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) pencere_n
    FROM e),
-- (b) REJIM MI: ayni donemde bagimsiz hucrelerin cogu ayni yone mi kaciyor
donem AS (
  SELECT tenant_id, hedef_donem,
         count(*) hucre_n,
         GREATEST(avg(CASE WHEN yon>0 THEN 1.0 ELSE 0.0 END),
                  1-avg(CASE WHEN yon>0 THEN 1.0 ELSE 0.0 END)) ortak_yon_pay
    FROM e GROUP BY 1,2),
-- (d) HANGI BILESEN: ayni hucrenin adet hatasi ciro hatasindan cok kucukse fiyat suclu
bilesen AS (
  SELECT c.id, c.mutlak_yuzde_hata ciro_hata, a.mutlak_yuzde_hata adet_hata
    FROM e c JOIN e a
      ON a.tenant_id=c.tenant_id AND a.varlik_tipi=c.varlik_tipi
     AND a.varlik_kodu=c.varlik_kodu AND a.model_ad=c.model_ad
     AND a.hedef_donem=c.hedef_donem AND a.nesne='adet'
   WHERE c.nesne='ciro')
SELECT i.id, i.tenant_id, i.nesne, i.varlik_tipi, i.varlik_kodu, i.model_ad, i.hedef_donem,
       round(100*i.goreli::numeric,1) goreli_hata_pct,
       CASE WHEN i.pencere_n < 4 THEN 'yetersiz'
            WHEN i.yukari_pay >= 0.83 OR i.yukari_pay <= 0.17 THEN 'sapma'
            ELSE 'gurultu' END AS sapma_mi,
       CASE WHEN d.hucre_n < 8 THEN 'yetersiz'
            WHEN d.ortak_yon_pay >= 0.75 THEN 'rejim'
            ELSE 'model' END AS rejim_mi,
       CASE WHEN i.nesne <> 'ciro' THEN NULL
            WHEN b.adet_hata IS NULL THEN 'bilinmiyor'
            WHEN b.adet_hata <= 0.5*b.ciro_hata THEN 'fiyat'
            WHEN b.adet_hata >= 0.8*b.ciro_hata THEN 'hacim'
            ELSE 'karisik' END AS bilesen,
       round(d.ortak_yon_pay::numeric,2) donem_ortak_yon,
       d.hucre_n donem_hucre_say
  FROM isaret i
  JOIN donem d ON d.tenant_id=i.tenant_id AND d.hedef_donem=i.hedef_donem
  LEFT JOIN bilesen b ON b.id=i.id;
