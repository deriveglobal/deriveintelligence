-- "NE OLUNCA NE OLUYOR" TARAYICISI
-- Her hedef x her surucu x 1..12 ay gecikme. Egitim penceresinde fit, MUHURLU
-- test penceresinde olcum. p_kaydir<>0 ise surucular zamanda kaydirilir = PLASEBO:
-- gercek hizalama bozulur, otokorelasyon korunur -> gurultu tabani olculur.
CREATE OR REPLACE FUNCTION bi_kesif_tara(
  p_tenant uuid,
  p_hedefler text[],
  p_max_lag integer DEFAULT 12,
  p_egitim_son date DEFAULT DATE '2025-04-01',
  p_kaydir integer DEFAULT 0)
RETURNS TABLE(hedef text, surucu text, gecikme integer,
              n_egitim integer, n_test integer,
              taban_mae numeric, model_mae numeric, kazanc_pct numeric)
LANGUAGE sql STABLE AS $fn$
WITH son AS (SELECT max(donem) d FROM mv_sinyal_panel
              WHERE donem < date_trunc('month',CURRENT_DATE)::date),
p AS (SELECT seri, donem, deger FROM mv_sinyal_panel
       WHERE tenant_id = p_tenant AND donem <= (SELECT d FROM son)),
dd AS (SELECT a.seri, a.donem, (a.deger - b.deger) AS d
         FROM p a JOIN p b ON b.seri = a.seri
              AND b.donem = (a.donem - interval '12 months')::date),
ds AS (SELECT seri, (donem + (p_kaydir||' months')::interval)::date AS donem, d FROM dd),
y  AS (SELECT * FROM dd WHERE seri = ANY(p_hedefler)),
lg AS (SELECT generate_series(1, p_max_lag) AS l),
j  AS (SELECT y.seri AS hedef, x.seri AS surucu, lg.l, y.donem, y.d AS yd, x.d AS xd
         FROM y CROSS JOIN lg
         JOIN ds x ON x.donem = (y.donem - (lg.l||' months')::interval)::date
        WHERE x.seri <> y.seri),
tr AS (SELECT hedef, surucu, l, count(*)::int AS n,
              avg(yd) AS ybar, regr_slope(yd,xd) AS b, regr_intercept(yd,xd) AS a
         FROM j WHERE donem <= p_egitim_son GROUP BY 1,2,3),
te AS (SELECT j.hedef, j.surucu, j.l, t.n AS n_tr, count(*)::int AS n_te,
              avg(abs(j.yd - t.ybar))                 AS base_mae,
              avg(abs(j.yd - (t.a + t.b * j.xd)))     AS mod_mae
         FROM j JOIN tr t ON t.hedef=j.hedef AND t.surucu=j.surucu AND t.l=j.l
        WHERE j.donem > p_egitim_son AND t.b IS NOT NULL AND t.n >= 18
        GROUP BY 1,2,3, t.n)
SELECT hedef, surucu, l::int, n_tr, n_te,
       round(base_mae::numeric, 2), round(mod_mae::numeric, 2),
       round((100*(base_mae - mod_mae)/NULLIF(base_mae,0))::numeric, 1)
  FROM te WHERE n_te >= 8;
$fn$;
