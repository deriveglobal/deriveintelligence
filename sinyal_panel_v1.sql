-- ADAY SERI FABRIKASI. Amac: ciroyu ciro ile tahmin etmeyi birakip,
-- ciro hareket etmeden ONCE hareket eden seyleri aday gosterge yapmak.
-- Sifir literal: cekirdek is filtresi evren_desen(), segment kategori_segment()'ten.
DROP MATERIALIZED VIEW IF EXISTS mv_sinyal_panel;
CREATE MATERIALIZED VIEW mv_sinyal_panel AS
WITH ten AS (SELECT t.tid, evren_desen(t.tid) AS desen FROM bi_tenant_listesi() t),
f AS (
  SELECT s.tenant_id::uuid AS tenant_id, date_trunc('month', s.fatura_tarihi)::date AS donem,
         s.musteri_kodu, s.fatura_no, s.kalem_kodu, s.kategori, s.marka,
         COALESCE(s.miktar,0)::numeric  AS miktar,
         COALESCE(s.satir_tutar,0)::numeric AS tutar,
         kategori_segment(s.kategori, s.tenant_id::uuid) AS segment
    FROM bi_satis_faturalari s
    JOIN ten ON ten.tid = s.tenant_id::uuid
   WHERE s.fatura_tarihi IS NOT NULL AND s.grup_adi LIKE ten.desen),
a AS (
  SELECT tenant_id, donem,
         sum(miktar) adet, sum(tutar) ciro,
         count(DISTINCT fatura_no)::numeric  fatura_say,
         count(*)::numeric                   satir_say,
         count(DISTINCT kalem_kodu)::numeric kalem_cesit,
         count(DISTINCT musteri_kodu)::numeric aktif_musteri
    FROM f GROUP BY 1,2),
ilk AS (SELECT tenant_id, musteri_kodu, min(donem) AS ilk_donem FROM f GROUP BY 1,2),
yeni AS (SELECT tenant_id, ilk_donem AS donem, count(*)::numeric yeni_musteri FROM ilk GROUP BY 1,2),
cuz AS (
  SELECT tenant_id, donem,
         (percentile_cont(0.5) WITHIN GROUP (ORDER BY k))::numeric AS cuzdan
    FROM (SELECT tenant_id, donem, musteri_kodu, count(DISTINCT kategori)::float k
            FROM f GROUP BY 1,2,3) x GROUP BY 1,2),
kons AS (
  SELECT tenant_id, donem,
         (sum(c) FILTER (WHERE rn<=10)/NULLIF(sum(c),0)*100)::numeric AS ilk10_pay
    FROM (SELECT tenant_id, donem, musteri_kodu, sum(tutar) c,
                 row_number() OVER (PARTITION BY tenant_id,donem ORDER BY sum(tutar) DESC) rn
            FROM f GROUP BY 1,2,3) y GROUP BY 1,2),
segp AS (
  SELECT tenant_id, donem, segment,
         sum(tutar) AS s_ciro, sum(miktar) AS s_adet,
         sum(tutar)/NULLIF(sum(sum(tutar)) OVER (PARTITION BY tenant_id,donem),0) AS pay
    FROM f WHERE segment IS NOT NULL GROUP BY 1,2,3),
ent AS (
  SELECT tenant_id, donem, (-sum(pay*ln(pay)))::numeric AS segment_entropi
    FROM segp WHERE pay > 0 GROUP BY 1,2),
mark AS (
  SELECT tenant_id, donem, (-sum(p*ln(p)))::numeric AS marka_entropi
    FROM (SELECT tenant_id, donem, marka,
                 sum(tutar)/NULLIF(sum(sum(tutar)) OVER (PARTITION BY tenant_id,donem),0) p
            FROM f WHERE marka IS NOT NULL GROUP BY 1,2,3) m
   WHERE p > 0 GROUP BY 1,2),
od AS (
  SELECT o.tenant_id::uuid AS tenant_id, date_trunc('month', o.odeme_tarihi)::date AS donem,
         avg(o.gecikme_gun)::numeric AS ort_gecikme_gun,
         (100.0*count(*) FILTER (WHERE o.gecikme_gun > 0)/NULLIF(count(*),0))::numeric AS gec_odeme_pay,
         sum(o.odenen_tutar)::numeric AS tahsilat_tutar,
         (100.0*count(*) FILTER (WHERE o.vade_tarihi = o.fatura_tarihi)
            /NULLIF(count(*),0))::numeric AS pesin_pay
    FROM bi_odeme_gecmisi o WHERE o.odeme_tarihi IS NOT NULL GROUP BY 1,2),
zy AS (
  SELECT tenant_id::uuid AS tenant_id, date_trunc('month', ziyaret_tarihi)::date AS donem,
         count(*)::numeric AS ziyaret_say,
         count(DISTINCT musteri_id)::numeric AS ziyaret_musteri
    FROM saha_ziyaret WHERE ziyaret_tarihi IS NOT NULL GROUP BY 1,2)
SELECT tenant_id, donem, seri, deger FROM (
  SELECT tenant_id, donem, 'adet'::text seri, adet deger FROM a
  UNION ALL SELECT tenant_id, donem, 'ciro',            ciro          FROM a
  UNION ALL SELECT tenant_id, donem, 'birim_fiyat',     ciro/NULLIF(adet,0) FROM a
  UNION ALL SELECT tenant_id, donem, 'fatura_say',      fatura_say    FROM a
  UNION ALL SELECT tenant_id, donem, 'sepet',           ciro/NULLIF(fatura_say,0) FROM a
  UNION ALL SELECT tenant_id, donem, 'satir_basi_tutar',ciro/NULLIF(satir_say,0)  FROM a
  UNION ALL SELECT tenant_id, donem, 'kalem_cesit',     kalem_cesit   FROM a
  UNION ALL SELECT tenant_id, donem, 'aktif_musteri',   aktif_musteri FROM a
  UNION ALL SELECT tenant_id, donem, 'musteri_basi_ciro', ciro/NULLIF(aktif_musteri,0) FROM a
  UNION ALL SELECT tenant_id, donem, 'yeni_musteri',    yeni_musteri  FROM yeni
  UNION ALL SELECT tenant_id, donem, 'cuzdan_genisligi',cuzdan        FROM cuz
  UNION ALL SELECT tenant_id, donem, 'ilk10_yogunlasma',ilk10_pay     FROM kons
  UNION ALL SELECT tenant_id, donem, 'segment_entropi', segment_entropi FROM ent
  UNION ALL SELECT tenant_id, donem, 'marka_entropi',   marka_entropi FROM mark
  UNION ALL SELECT tenant_id, donem, 'ort_gecikme_gun', ort_gecikme_gun FROM od
  UNION ALL SELECT tenant_id, donem, 'gec_odeme_pay',   gec_odeme_pay FROM od
  UNION ALL SELECT tenant_id, donem, 'tahsilat_tutar',  tahsilat_tutar FROM od
  UNION ALL SELECT tenant_id, donem, 'pesin_pay',       pesin_pay     FROM od
  UNION ALL SELECT tenant_id, donem, 'ziyaret_say',     ziyaret_say   FROM zy
  UNION ALL SELECT tenant_id, donem, 'ziyaret_musteri', ziyaret_musteri FROM zy
  UNION ALL SELECT tenant_id, donem, 'seg_ciro:'||segment,  s_ciro FROM segp
  UNION ALL SELECT tenant_id, donem, 'seg_adet:'||segment,  s_adet FROM segp
  UNION ALL SELECT tenant_id, donem, 'seg_fiyat:'||segment, s_ciro/NULLIF(s_adet,0) FROM segp
  UNION ALL SELECT tenant_id, donem, 'seg_pay:'||segment,   pay*100 FROM segp
) u WHERE deger IS NOT NULL AND donem >= DATE '2021-11-01';

CREATE UNIQUE INDEX mv_sinyal_panel_uq ON mv_sinyal_panel (tenant_id, seri, donem);
