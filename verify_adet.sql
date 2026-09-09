-- verify_adet.sql — LASTİK ADET pencere doğrulama (READONLY). Kokpit "Adet" kartını kaynağa karşı çöz.
-- Ekran değerleri: "Bu ay" = 19.733 · "Yıl Başı" = 66.877. Aşağıdaki pencerelerden HANGİSİ 19.733'e eşitse
-- kartın gerçek penceresi odur (ve kart kaynağı doğru okuyor demektir). Bugün: 2026-07-25; satış feed son: 2026-07-22.
\pset pager off
SELECT id::text AS tid FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1 \gset

\echo '=== 1) LASTİK adet — pencere bazlı (grup_adi = LASTIK TUKETICI/TICARI) ==='
WITH s AS (SELECT fatura_tarihi d, miktar FROM bi_satis_faturalari
           WHERE tenant_id::text=:'tid' AND miktar>0 AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI'))
SELECT 'Temmuz (takvim ayı, 07-01 den)'      AS pencere, round(SUM(miktar))::bigint AS adet FROM s WHERE d >= '2026-07-01'
UNION ALL SELECT 'Haziran (06-01..07-01)',           round(SUM(miktar))::bigint FROM s WHERE d >= '2026-06-01' AND d < '2026-07-01'
UNION ALL SELECT 'Haziran-01 den bugune',            round(SUM(miktar))::bigint FROM s WHERE d >= '2026-06-01'
UNION ALL SELECT 'Son 30 gun',                       round(SUM(miktar))::bigint FROM s WHERE d >= CURRENT_DATE - 30
UNION ALL SELECT 'Yil Basi (01-01 den) = YTD',       round(SUM(miktar))::bigint FROM s WHERE d >= '2026-01-01';

\echo ''
\echo '=== 2) KIYAS: TÜM ürünler (lastik filtresi YOK) aynı pencereler — kart lastik mi tüm mü? ==='
WITH a AS (SELECT fatura_tarihi d, miktar FROM bi_satis_faturalari WHERE tenant_id::text=:'tid' AND miktar>0)
SELECT 'TÜM · Temmuz'         AS pencere, round(SUM(miktar))::bigint AS adet FROM a WHERE d >= '2026-07-01'
UNION ALL SELECT 'TÜM · Haziran-01 den', round(SUM(miktar))::bigint FROM a WHERE d >= '2026-06-01'
UNION ALL SELECT 'TÜM · Yil Basi',       round(SUM(miktar))::bigint FROM a WHERE d >= '2026-01-01';

\echo ''
\echo '=== 3) grup_adi dağılımı (lastik grup adları gerçekten bunlar mı?) ==='
SELECT COALESCE(NULLIF(TRIM(grup_adi),''),'(boş)') grup_adi, round(SUM(miktar))::bigint adet_12ay
FROM bi_satis_faturalari WHERE tenant_id::text=:'tid' AND miktar>0 AND fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY 1 ORDER BY 2 DESC LIMIT 12;
