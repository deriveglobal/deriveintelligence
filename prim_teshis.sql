-- TEŞVİK/PRİM KAZANCI teşhis (READ-ONLY). Kaynak: bi_satis_faturalari kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM').
-- Amaç: dönem pencerelerinde (bu ay / 3 / 6 / 12 / yıl başı) gerçek prim tutarı sağlıklı mı, kategori dağılımı ne.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo '===== 1) hangi kategoriler prim? tutar + satir sayisi (son 12 ay) ====='
SELECT kategori, round(sum(satir_tutar)/1e6,2) tutar_m, count(*) satir
  FROM bi_satis_faturalari
 WHERE tenant_id::text=:'t' AND fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month'
   AND kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
 GROUP BY kategori ORDER BY tutar_m DESC;

\echo '===== 2) DONEM PENCERELERI — prim tutari (M TL) ====='
SELECT
  round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE))/1e6,2)                        buay_m,
  round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '2 month')/1e6,2)     son3_m,
  round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '5 month')/1e6,2)     son6_m,
  round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month')/1e6,2)    son12_m,
  round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('year',CURRENT_DATE))/1e6,2)                         yilbasi_m
  FROM bi_satis_faturalari
 WHERE tenant_id::text=:'t' AND kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM');

\echo '===== 3) AYLIK trend — prim gercekten her ay akiyor mu yoksa tek seferlik mi (seyreklik testi) ====='
SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay, round(sum(satir_tutar)/1e6,2) tutar_m, count(*) satir
  FROM bi_satis_faturalari
 WHERE tenant_id::text=:'t' AND fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month'
   AND kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
 GROUP BY 1 ORDER BY 1;

\echo '===== 4) referans: son 12 ay net satis (lastik) — prim/ciro orani mantikli mi ====='
SELECT round(sum(satir_tutar)/1e6,1) net_satis_lastik_m
  FROM bi_satis_faturalari
 WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi >= CURRENT_DATE-365 AND grup_adi LIKE 'LASTIK%';
