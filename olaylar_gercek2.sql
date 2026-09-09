-- MUSTERI_OLAYLAR gerçek-veri (READ-ONLY, \gset YOK) — Taci Oto Lastik zaman çizelgesi.
-- Hedef müşteri isimle seçilir; her blok kendi alt-sorgusuyla çözer (meta-komut yok, takılmaz).

\echo '================ HEDEF ================'
SELECT firma, tip, musteri_kodu,
       (SELECT durum FROM saha_musteri_saglik sg WHERE sg.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND sg.musteri_kodu=m.musteri_kodu) durum,
       (SELECT ritim FROM saha_musteri_saglik sg WHERE sg.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND sg.musteri_kodu=m.musteri_kodu) ritim_ay,
       (SELECT recency_ay FROM saha_musteri_saglik sg WHERE sg.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND sg.musteri_kodu=m.musteri_kodu) recency_ay
  FROM saha_musteri m
 WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND firma ILIKE '%Taci Oto%' AND aktif=true
 ORDER BY firma LIMIT 1;

\echo ''
\echo '================ ZAMAN ÇİZELGESİ (son 20, birleşik) ================'
SELECT to_char(ts,'DD.MM.YY') tarih, tip, left(ozet,88) ozet FROM (
  SELECT z.ziyaret_tarihi::timestamptz ts, 'ziyaret' tip, COALESCE(z.notlar,'(not girilmemiş)') ozet
    FROM saha_ziyaret z WHERE z.tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND z.durum='TAMAMLANDI'
      AND z.musteri_id=(SELECT id FROM saha_musteri WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND firma ILIKE '%Taci Oto%' AND aktif=true ORDER BY firma LIMIT 1)
  UNION ALL
  SELECT f.fatura_tarihi::timestamptz, 'alim', COALESCE(f.marka,'')||' '||COALESCE(f.ebat,'')||' — '||round(f.satir_tutar)::text||' TL'
    FROM bi_satis_faturalari f WHERE f.tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
      AND f.musteri_kodu=(SELECT musteri_kodu FROM saha_musteri WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND firma ILIKE '%Taci Oto%' AND aktif=true ORDER BY firma LIMIT 1)
  UNION ALL
  SELECT s.created_at, 'sinyal/'||COALESCE(s.tip,'not'), s.ozet FROM saha_sinyal s WHERE s.tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
      AND s.musteri_id=(SELECT id FROM saha_musteri WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND firma ILIKE '%Taci Oto%' AND aktif=true ORDER BY firma LIMIT 1)
) x ORDER BY ts DESC LIMIT 20;

\echo ''
\echo '================ EKG — aylık ciro (12 ay) ================'
SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay, round(SUM(satir_tutar))::text ciro
  FROM bi_satis_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
    AND musteri_kodu=(SELECT musteri_kodu FROM saha_musteri WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND firma ILIKE '%Taci Oto%' AND aktif=true ORDER BY firma LIMIT 1)
    AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months')
 GROUP BY 1 ORDER BY 1;

\echo ''
\echo '================ SON 3 GERÇEK ZİYARET NOTU ================'
SELECT to_char(ziyaret_tarihi,'DD.MM.YY') tarih, left(notlar,180) not_metni
  FROM saha_ziyaret WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND durum='TAMAMLANDI' AND notlar IS NOT NULL
    AND musteri_id=(SELECT id FROM saha_musteri WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND firma ILIKE '%Taci Oto%' AND aktif=true ORDER BY firma LIMIT 1)
 ORDER BY ziyaret_tarihi DESC LIMIT 3;
