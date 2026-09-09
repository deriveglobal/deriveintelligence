-- MUSTERI_OLAYLAR gerçek-veri dökümü (READ-ONLY) — bir soğuyan müşterinin gerçek zaman çizelgesi.
-- Kartı gerçek veriyle kurmak için: seçilen müşteri + olaylar + EKG + gerçek ziyaret notları.
\set T 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

-- Hedef: en yüksek cirolu, ziyareti olan bir SOĞUYOR/PASİF müşteri
WITH ciro AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari
              WHERE tenant_id::text=:'T' AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu)
SELECT m.id AS mid, m.musteri_kodu AS kod, m.firma AS firma, m.tip AS tip,
       sg.durum AS durum, sg.ritim AS ritim, sg.recency_ay AS recency
  FROM saha_musteri m
  JOIN saha_musteri_saglik sg ON sg.tenant_id=:'T' AND sg.musteri_kodu=m.musteri_kodu
  LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
 WHERE m.tenant_id::text=:'T' AND m.aktif=true AND sg.durum IN ('soguyor','pasif')
   AND (SELECT COUNT(*) FROM saha_ziyaret z WHERE z.tenant_id::text=:'T' AND z.musteri_id=m.id AND z.durum='TAMAMLANDI' AND z.notlar IS NOT NULL) >= 2
 ORDER BY COALESCE(c.yil,0) DESC LIMIT 1
\gset

\echo '================ HEDEF MÜŞTERİ ================'
\echo :firma '·' :durum '· ritim' :ritim 'ay · recency' :recency 'ay · kod' :kod

\echo ''
\echo '================ ZAMAN ÇİZELGESİ (son 20 olay, birleşik) ================'
SELECT to_char(ts,'DD.MM.YY') tarih, tip, left(ozet,90) ozet FROM (
  SELECT ziyaret_tarihi::timestamptz ts, 'ziyaret' tip, COALESCE(notlar,'(not girilmemiş)') ozet
    FROM saha_ziyaret WHERE tenant_id::text=:'T' AND musteri_id=:'mid' AND durum='TAMAMLANDI'
  UNION ALL SELECT created_at, 'sinyal/'||COALESCE(tip,'not'), ozet FROM saha_sinyal WHERE tenant_id::text=:'T' AND musteri_id=:'mid'
  UNION ALL SELECT fatura_tarihi::timestamptz, 'alim', COALESCE(marka,'')||' '||COALESCE(ebat,'')||' — '||round(satir_tutar)::text||' TL'
    FROM bi_satis_faturalari WHERE tenant_id::text=:'T' AND musteri_kodu=:'kod'
  UNION ALL SELECT created_at, 'teklif', COALESCE(marka,'')||' '||COALESCE(ebat,'')||' · '||COALESCE(durum,'') FROM saha_teklif WHERE tenant_id::text=:'T' AND musteri_id=:'mid'
  UNION ALL SELECT created_at, 'rakip', COALESCE(rakip_marka,'')||' '||COALESCE(ebat,'') FROM saha_rakip_teklif WHERE tenant_id::text=:'T' AND musteri_id=:'mid'
) x ORDER BY ts DESC LIMIT 20;

\echo ''
\echo '================ EKG — aylık ciro (12 ay) ================'
SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay, round(SUM(satir_tutar))::text ciro
  FROM bi_satis_faturalari WHERE tenant_id::text=:'T' AND musteri_kodu=:'kod' AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months')
 GROUP BY 1 ORDER BY 1;

\echo ''
\echo '================ SON 3 GERÇEK ZİYARET NOTU (tam metin) ================'
SELECT to_char(ziyaret_tarihi,'DD.MM.YY') tarih, left(notlar,180) not_metni
  FROM saha_ziyaret WHERE tenant_id::text=:'T' AND musteri_id=:'mid' AND durum='TAMAMLANDI' AND notlar IS NOT NULL
 ORDER BY ziyaret_tarihi DESC LIMIT 3;

\echo ''
\echo '================ SAYAÇLAR ================'
SELECT
  (SELECT COUNT(*) FROM saha_ziyaret WHERE tenant_id::text=:'T' AND musteri_id=:'mid' AND durum='TAMAMLANDI') ziyaret,
  (SELECT COUNT(*) FROM bi_satis_faturalari WHERE tenant_id::text=:'T' AND musteri_kodu=:'kod') alim,
  (SELECT COUNT(*) FROM saha_sinyal WHERE tenant_id::text=:'T' AND musteri_id=:'mid') sinyal,
  (SELECT COUNT(*) FROM saha_teklif WHERE tenant_id::text=:'T' AND musteri_id=:'mid') teklif;
