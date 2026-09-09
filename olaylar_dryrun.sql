-- MUSTERI_OLAYLAR dry-run (READ-ONLY) — gerçek soğuyan/pasif müşterilerde olay zenginliği + özet malzemesi.
-- Amaç: zaman çizelgesi/özet-cümlesi gerçek veriyle doluyor mu, UI'ya bağlamadan gör.
-- Ön koşul: saha_musteri_saglik view CANLI. tenant KRB.
\set T 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo '=== En yüksek cirolu 8 SOĞUYOR/PASİF müşteride olay sayıları + son alım/ziyaret + açık takip ==='
WITH ciro AS (
  SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari
   WHERE tenant_id::text=:'T' AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu
)
SELECT m.firma,
       sg.durum, sg.ritim ritim_ay, sg.recency_ay,
       to_char(COALESCE(c.yil,0),'FM999G999G999') ciro_12ay,
       (SELECT COUNT(*) FROM saha_ziyaret z WHERE z.tenant_id::text=:'T' AND z.musteri_id=m.id AND z.durum='TAMAMLANDI') ziyaret,
       (SELECT COUNT(*) FROM saha_sinyal s WHERE s.tenant_id::text=:'T' AND s.musteri_id=m.id) sinyal,
       (SELECT COUNT(*) FROM saha_teklif t WHERE t.tenant_id::text=:'T' AND t.musteri_id=m.id) teklif,
       (SELECT COUNT(*) FROM saha_rakip_teklif r WHERE r.tenant_id::text=:'T' AND r.musteri_id=m.id) rakip,
       (SELECT COUNT(*) FROM saha_musteri_aksiyon a WHERE a.tenant_id::text=:'T' AND a.musteri_id=m.id) aksiyon,
       (SELECT COUNT(*) FROM bi_satis_faturalari f WHERE f.tenant_id::text=:'T' AND f.musteri_kodu=m.musteri_kodu) alim,
       (SELECT to_char(MAX(f.fatura_tarihi),'DD.MM.YY') FROM bi_satis_faturalari f WHERE f.tenant_id::text=:'T' AND f.musteri_kodu=m.musteri_kodu) son_alim,
       (SELECT to_char(MAX(z.ziyaret_tarihi),'DD.MM.YY') FROM saha_ziyaret z WHERE z.tenant_id::text=:'T' AND z.musteri_id=m.id AND z.durum='TAMAMLANDI') son_ziyaret,
       (SELECT COUNT(*) FROM saha_sinyal s WHERE s.tenant_id::text=:'T' AND s.musteri_id=m.id AND (s.tip='takip' OR s.detay ? 'takip_tarihi') AND COALESCE((s.detay->>'kapandi')::boolean,false)=false) acik_takip
  FROM saha_musteri m
  JOIN saha_musteri_saglik sg ON sg.tenant_id=:'T' AND sg.musteri_kodu=m.musteri_kodu
  LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
 WHERE m.tenant_id::text=:'T' AND m.aktif=true AND sg.durum IN ('soguyor','pasif')
 ORDER BY COALESCE(c.yil,0) DESC
 LIMIT 8;

\echo ''
\echo '=== Saha içeriği ne kadar dolu? (özet cümlesi + timeline için) ==='
SELECT 'saha_sinyal (not/rakip/takip)' kaynak, COUNT(*) toplam, COUNT(DISTINCT musteri_id) musteri FROM saha_sinyal WHERE tenant_id::text=:'T'
UNION ALL SELECT 'saha_ziyaret notlu', COUNT(*), COUNT(DISTINCT musteri_id) FROM saha_ziyaret WHERE tenant_id::text=:'T' AND durum='TAMAMLANDI' AND notlar IS NOT NULL
UNION ALL SELECT 'saha_teklif', COUNT(*), COUNT(DISTINCT musteri_id) FROM saha_teklif WHERE tenant_id::text=:'T'
UNION ALL SELECT 'saha_rakip_teklif', COUNT(*), COUNT(DISTINCT musteri_id) FROM saha_rakip_teklif WHERE tenant_id::text=:'T'
UNION ALL SELECT 'saha_musteri_aksiyon', COUNT(*), COUNT(DISTINCT musteri_id) FROM saha_musteri_aksiyon WHERE tenant_id::text=:'T';
