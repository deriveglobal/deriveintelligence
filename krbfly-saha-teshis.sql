\pset pager off
\echo '=== 1) saha_musteri kolonlari ==='
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name='saha_musteri' ORDER BY ordinal_position;

\echo '=== 2) 2501 ticari kodun saha eslesmesi + il/ilce/segment doluluk ==='
WITH tk AS (
  SELECT DISTINCT ON (m.musteri_kodu) m.musteri_kodu AS kod, m.sehir
  FROM master_musteri m
  JOIN (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, grup FROM bi_musteri_risk
        WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND musteri_mi
        ORDER BY muhatap_kodu, export_date DESC NULLS LAST) r ON r.muhatap_kodu=m.musteri_kodu
  WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
    AND r.grup IN ('FILO TICARI','TOPTAN','KURUM','IMALATCI','IHRACAT','GRUP MUSTERILERI')
  ORDER BY m.musteri_kodu
),
s AS (SELECT DISTINCT ON (musteri_kodu) musteri_kodu AS kod, il, ilce, segment, sektorler
      FROM saha_musteri WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND musteri_kodu IS NOT NULL
      ORDER BY musteri_kodu, aktif DESC, updated_at DESC NULLS LAST)
SELECT count(*) AS ticari,
       count(s.kod) AS saha_eslesen,
       count(*) FILTER (WHERE COALESCE(s.ilce,'')<>'') AS ilceli,
       count(*) FILTER (WHERE COALESCE(s.segment,'')<>'') AS segmentli,
       count(*) FILTER (WHERE s.sektorler IS NOT NULL AND array_length(s.sektorler,1)>0) AS sektorlu
FROM tk LEFT JOIN s ON s.kod=tk.kod;

\echo '=== 3) segment distinct (esleme tablosu icin) ==='
SELECT segment, count(*) FROM saha_musteri
WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND COALESCE(segment,'')<>''
GROUP BY segment ORDER BY count DESC;

\echo '=== 4) sektorler array degerleri ==='
SELECT unnest(sektorler) AS sektor, count(*) FROM saha_musteri
WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND sektorler IS NOT NULL
GROUP BY 1 ORDER BY 2 DESC;
