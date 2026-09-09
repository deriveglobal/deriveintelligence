\pset pager off
\echo '=== 1) master_musteri kolonlari ==='
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name='master_musteri' ORDER BY ordinal_position;

\echo '=== 2) bi_musteri_risk kolonlari ==='
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name='bi_musteri_risk' ORDER BY ordinal_position;

\echo '=== 3) master_musteri toplam + alan doluluk (KRB tenant) ==='
SELECT count(*) AS master_toplam,
       count(*) FILTER (WHERE musteri_kodu   IS NOT NULL AND musteri_kodu<>'')  AS kodlu,
       count(*) FILTER (WHERE vergi_no        IS NOT NULL AND vergi_no<>'')      AS vknli,
       count(*) FILTER (WHERE musteri_adi     IS NOT NULL AND musteri_adi<>'')   AS isimli
FROM master_musteri
WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';

\echo '=== 4) bi_musteri_risk.grup dagilimi (musteri sayisi) ==='
SELECT grup, count(DISTINCT muhatap_kodu) AS musteri
FROM bi_musteri_risk
WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND musteri_mi
GROUP BY grup ORDER BY musteri DESC;

\echo '=== 5) master ⋈ risk: kac master carinin grup etiketi var ==='
SELECT count(*) FILTER (WHERE r.grup IS NOT NULL) AS grup_var,
       count(*) FILTER (WHERE r.grup IS NULL)     AS grup_yok
FROM master_musteri m
LEFT JOIN (
  SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, grup
  FROM bi_musteri_risk
  WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND musteri_mi
) r ON r.muhatap_kodu = m.musteri_kodu
WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';
