-- FINANS ÖRÜNTÜ & KORELASYON teşhis (READ-ONLY). İktisatçı katmanı ilk tuğla — verinin GERÇEK örüntüleri.
-- Postgres corr()/regr_count() ile deterministik. 12-15 aylık seriler; n düşükse yön-göstergesi (kesin değil).
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '========================================================'
\echo '§1  AYLIK MATRİS (seriler — sanity; her ay bir satır)'
\echo '========================================================'
WITH atom AS (
  SELECT date_trunc('month',ay)::date m,
         round(sum(ciro)/1e6,2) ciro_m,
         round(100*sum(brut_kar)/nullif(sum(ciro),0),2) marj_pct,
         round(sum(ciro-brut_kar)/1e6,2) smm_m,
         round(sum(-brut_kar) FILTER (WHERE brut_kar<0)/1e6,2) sizinti_m
    FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '14 month'
   GROUP BY 1),
prim AS (
  SELECT date_trunc('month',fatura_tarihi)::date m, round(sum(satir_tutar)/1e6,2) prim_m
    FROM bi_satis_faturalari f WHERE f.tenant_id::text=:'t'
     AND f.kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
     AND EXISTS (SELECT 1 FROM bi_musteri_risk r WHERE r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu AND r.grup ILIKE '%TEDAR%')
     AND fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '14 month'
   GROUP BY 1),
mg AS (
  SELECT date_trunc('month',donem)::date m,
         round(max(deger) FILTER (WHERE metrik='dso'))::int dso,
         round(max(deger) FILTER (WHERE metrik='alacak')/1e6,2) alacak_m,
         round(max(deger) FILTER (WHERE metrik='stok_deger')/1e6,2) stok_m
    FROM bi_metrik_gecmis WHERE tenant_id::text=:'t' AND boyut_tipi='sirket' AND periyot='ay'
     AND metrik IN ('dso','alacak','stok_deger') AND donem >= date_trunc('month',CURRENT_DATE)-INTERVAL '14 month'
   GROUP BY 1)
SELECT to_char(a.m,'YYYY-MM') ay, a.ciro_m, a.marj_pct, a.smm_m, a.sizinti_m,
       p.prim_m, mg.dso, mg.alacak_m, mg.stok_m
  FROM atom a LEFT JOIN prim p ON p.m=a.m LEFT JOIN mg ON mg.m=a.m
 ORDER BY a.m;

\echo '========================================================'
\echo '§2  KORELASYON MATRİSİ  (r = Pearson, n = ortak ay sayısı)  |r|>=0,5 & n>=10 = anlamlı yön'
\echo '========================================================'
WITH atom AS (
  SELECT date_trunc('month',ay)::date m, sum(ciro) ciro, sum(ciro-brut_kar) smm,
         100.0*sum(brut_kar)/nullif(sum(ciro),0) marj, sum(-brut_kar) FILTER (WHERE brut_kar<0) sizinti
    FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '14 month' GROUP BY 1),
prim AS (
  SELECT date_trunc('month',fatura_tarihi)::date m, sum(satir_tutar) prim
    FROM bi_satis_faturalari f WHERE f.tenant_id::text=:'t' AND f.kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
     AND EXISTS (SELECT 1 FROM bi_musteri_risk r WHERE r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu AND r.grup ILIKE '%TEDAR%')
     AND fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '14 month' GROUP BY 1),
mg AS (
  SELECT date_trunc('month',donem)::date m,
         max(deger) FILTER (WHERE metrik='dso') dso,
         max(deger) FILTER (WHERE metrik='alacak') alacak,
         max(deger) FILTER (WHERE metrik='stok_deger') stok
    FROM bi_metrik_gecmis WHERE tenant_id::text=:'t' AND boyut_tipi='sirket' AND periyot='ay'
     AND metrik IN ('dso','alacak','stok_deger') AND donem >= date_trunc('month',CURRENT_DATE)-INTERVAL '14 month' GROUP BY 1),
w AS (SELECT a.m, a.ciro, a.smm, a.marj, a.sizinti, p.prim, mg.dso, mg.alacak, mg.stok
        FROM atom a LEFT JOIN prim p ON p.m=a.m LEFT JOIN mg ON mg.m=a.m)
SELECT ' ilişki '||x AS iliski, r, n, CASE WHEN abs(r)>=0.5 AND n>=10 THEN CASE WHEN r>0 THEN '↑ birlikte' ELSE '↓ ters' END ELSE '· zayıf/az' END yorum FROM (
  SELECT 'marj ~ dso (yavaş tahsilat marja mı mal oluyor)' x, round(corr(marj,dso)::numeric,2) r, regr_count(marj,dso) n FROM w
  UNION ALL SELECT 'marj ~ ciro (hacim-marj ödünleşmesi)', round(corr(marj,ciro)::numeric,2), regr_count(marj,ciro) FROM w
  UNION ALL SELECT 'ciro ~ prim (teşvik hacimle mi geliyor)', round(corr(ciro,prim)::numeric,2), regr_count(ciro,prim) FROM w
  UNION ALL SELECT 'marj ~ prim (teşvik marjla ilişki)', round(corr(marj,prim)::numeric,2), regr_count(marj,prim) FROM w
  UNION ALL SELECT 'sizinti ~ marj (sızıntı marjı yiyor mu)', round(corr(sizinti,marj)::numeric,2), regr_count(sizinti,marj) FROM w
  UNION ALL SELECT 'sizinti ~ ciro (hacim büyüdükçe sızıntı)', round(corr(sizinti,ciro)::numeric,2), regr_count(sizinti,ciro) FROM w
  UNION ALL SELECT 'dso ~ alacak', round(corr(dso,alacak)::numeric,2), regr_count(dso,alacak) FROM w
  UNION ALL SELECT 'stok ~ marj (stok baskısı marja)', round(corr(stok,marj)::numeric,2), regr_count(stok,marj) FROM w
  UNION ALL SELECT 'stok ~ ciro', round(corr(stok,ciro)::numeric,2), regr_count(stok,ciro) FROM w
  UNION ALL SELECT 'alacak ~ ciro (satış artınca alacak)', round(corr(alacak,ciro)::numeric,2), regr_count(alacak,ciro) FROM w
  UNION ALL SELECT 'prim ~ sizinti', round(corr(prim,sizinti)::numeric,2), regr_count(prim,sizinti) FROM w
  UNION ALL SELECT 'ciro ~ smm (sanity, yüksek olmalı)', round(corr(ciro,smm)::numeric,2), regr_count(ciro,smm) FROM w
) s ORDER BY abs(r) DESC NULLS LAST;

\echo '========================================================'
\echo '§3  KONSANTRASYON  (Herfindahl HHI 0..1; top-N pay %)  — risk kaç elde toplanmış'
\echo '========================================================'
\echo '--- 3a) Marka MARJI (brüt kâr) konsantrasyonu (12 ay) ---'
WITH b AS (SELECT marka, sum(brut_kar) v FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365 AND brut_kar>0 GROUP BY 1)
SELECT count(*) marka_say, round(sum(v)/1e6,1) toplam_brutkar_m,
       round(sum(power(v/nullif((SELECT sum(v) FROM b),0),2))::numeric,3) hhi,
       round(100*(SELECT sum(v) FROM (SELECT v FROM b ORDER BY v DESC LIMIT 3) x)/nullif(sum(v),0))::int top3_pct FROM b;
\echo '--- 3b) Fiyat SIZINTISI (maliyet-altı brüt kâr) marka konsantrasyonu (12 ay) ---'
WITH b AS (SELECT marka, sum(-brut_kar) v FROM bi_marj_atom WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365 AND brut_kar<0 GROUP BY 1)
SELECT count(*) marka_say, round(sum(v)/1e6,1) toplam_sizinti_m,
       round(sum(power(v/nullif((SELECT sum(v) FROM b),0),2))::numeric,3) hhi,
       round(100*(SELECT sum(v) FROM (SELECT v FROM b ORDER BY v DESC LIMIT 3) x)/nullif(sum(v),0))::int top3_pct FROM b;
\echo '--- 3c) Kazanılan TEŞVİK muhatap konsantrasyonu (12 ay) ---'
WITH b AS (SELECT f.musteri_kodu, sum(f.satir_tutar) v FROM bi_satis_faturalari f
            WHERE f.tenant_id::text=:'t' AND f.kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM') AND f.fatura_tarihi>=CURRENT_DATE-365
              AND EXISTS (SELECT 1 FROM bi_musteri_risk r WHERE r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu AND r.grup ILIKE '%TEDAR%')
            GROUP BY 1)
SELECT count(*) muhatap_say, round(sum(v)/1e6,1) toplam_tesvik_m,
       round(sum(power(v/nullif((SELECT sum(v) FROM b),0),2))::numeric,3) hhi,
       round(100*(SELECT sum(v) FROM (SELECT v FROM b ORDER BY v DESC LIMIT 2) x)/nullif(sum(v),0))::int top2_pct FROM b;

\echo '========================================================'
\echo '§4  ÖRTÜŞME  — sızıntı markaları AYNI ZAMANDA ölü-stok markaları mı? (yan yana)'
\echo '========================================================'
WITH siz AS (SELECT marka, round(sum(-brut_kar)/1e6,2) sizinti_m FROM bi_marj_atom
              WHERE tenant_id::text=:'t' AND ay>=CURRENT_DATE-365 AND brut_kar<0 GROUP BY 1),
olu AS (SELECT bsd.marka, round(sum(bsd.toplam_deger)/1e6,2) olu_stok_m
          FROM bi_stok_durumu bsd WHERE bsd.tenant_id::text=:'t'
           AND bsd.export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=:'t')
           AND bsd.grup_adi ILIKE 'LASTIK%' AND bsd.eldeki_miktar>0
           AND NOT EXISTS (SELECT 1 FROM bi_stok_hareket h WHERE h.tenant_id::text=:'t' AND h.kalem_kodu=bsd.kalem_kodu AND h.cikis>0 AND h.belge_tarihi>=now()-INTERVAL '90 days')
         GROUP BY 1)
SELECT COALESCE(siz.marka,olu.marka) marka, siz.sizinti_m, olu.olu_stok_m,
       CASE WHEN siz.marka IS NOT NULL AND olu.marka IS NOT NULL THEN '⚠ İKİSİ' WHEN siz.marka IS NOT NULL THEN 'sızıntı' ELSE 'ölü stok' END durum
  FROM siz FULL JOIN olu ON siz.marka=olu.marka
 WHERE COALESCE(siz.sizinti_m,0)>0.1 OR COALESCE(olu.olu_stok_m,0)>0.5
 ORDER BY COALESCE(siz.sizinti_m,0)+COALESCE(olu.olu_stok_m,0) DESC LIMIT 15;
