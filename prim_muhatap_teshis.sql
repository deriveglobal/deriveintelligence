\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\echo '===== 1) OZET — kategori TEDARIKCI mi MUSTERI mi (son 12 ay) ====='
SELECT f.kategori,
       CASE WHEN r.grup ILIKE '%TEDAR%' THEN 'TEDARIKCI (uretici/ithalatci)'
            WHEN r.grup IS NULL THEN 'eslesmedi (risk tablosunda yok)'
            ELSE 'MUSTERI/diger ('||r.grup||')' END AS muhatap_tipi,
       round(sum(f.satir_tutar)/1e6,2) tutar_m, count(*) satir
  FROM bi_satis_faturalari f
  LEFT JOIN bi_musteri_risk r ON r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu
 WHERE f.tenant_id::text=:'t'
   AND f.fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month'
   AND f.kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
 GROUP BY 1,2 ORDER BY 1, tutar_m DESC;
\echo '===== 2) ISIM ISIM — en cok kime kesilmis (top 20) ====='
SELECT f.kategori,
       COALESCE(NULLIF(f.musteri_adi,''), f.musteri_kodu) muhatap,
       COALESCE(r.grup,'-') grup,
       round(sum(f.satir_tutar)/1e6,2) tutar_m, count(*) satir
  FROM bi_satis_faturalari f
  LEFT JOIN bi_musteri_risk r ON r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu
 WHERE f.tenant_id::text=:'t'
   AND f.fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month'
   AND f.kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
 GROUP BY 1,2,3 ORDER BY tutar_m DESC LIMIT 20;
