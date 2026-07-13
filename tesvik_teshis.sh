#!/usr/bin/env bash
# ⚠ NEDEN _ikame BOS CIKTI? Maliyet yazmadan ONCE gormem sart.
#   Fallback ("bulamazsan son alisa dus") hatayi GIZLIYORDU.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

$PSQL <<SQL
SET app.current_tenant_id = '$TEN';

\echo '=== 1) FIYAT LISTELERI — hangi marka, hangi kolon DOLU? ==='
SELECT u.marka, u.kategori, u.segment, u.aktif, u.kdv_haric,
       u.liste_tarihi, count(k.id) AS kalem,
       count(k.bayi_fiyati)     AS bayi_dolu,
       count(k.net_fiyati)      AS net_dolu,
       count(k.liste_fiyati)    AS liste_dolu,
       count(k.perakende_fiyati) AS perakende_dolu
  FROM bi_fiyat_listesi_uploads u
  LEFT JOIN bi_fiyat_listesi_kalemler k ON k.upload_id=u.id
 WHERE u.tenant_id='$TEN'::uuid
 GROUP BY 1,2,3,4,5,6
 ORDER BY u.marka, u.liste_tarihi DESC;

\echo ''
\echo '=== 2) ORNEK SATIRLAR — rakamlar hangi kolonda? ==='
SELECT u.marka, k.ebat, k.desen,
       k.liste_fiyati, k.bayi_fiyati, k.net_fiyati, k.perakende_fiyati, u.kdv_haric
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
 WHERE u.tenant_id='$TEN'::uuid AND u.aktif
 ORDER BY random() LIMIT 10;

\echo ''
\echo '=== 3) TESVIK TABLOSU — dolu mu, bos mu? ==='
SELECT marka, yil, segment, kanal,
       fatura_alti_pct, donem_primi_pct, sellout_primi_pct,
       kanal_operasyon_pct, kesin_siparis_pct, max_toplam_pct
  FROM bi_tedarikci_tesvik
 WHERE tenant_id='$TEN'::uuid
 ORDER BY marka, yil DESC, segment;

\echo ''
\echo '=== 4) ⚠ SATISTAKI MARKA ADI = LISTEDEKI MARKA ADI mi? ==='
\echo '   (eslesmiyorsa join sessizce SIFIR doner — tam da olan bu olabilir)'
SELECT 'LISTEDE' AS nerede, marka FROM bi_fiyat_listesi_uploads
 WHERE tenant_id='$TEN'::uuid GROUP BY 2
UNION ALL
SELECT 'SATISTA', marka FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND ebat IS NOT NULL
   AND fatura_tarihi >= CURRENT_DATE-365
 GROUP BY 2 HAVING sum(satir_tutar) > 5e6
 ORDER BY 1, 2;

\echo ''
\echo '=== 5) ⚠ EBAT FORMATI AYNI MI? (205/55R16 vs 205/55 R16 vs 2055516) ==='
SELECT 'LISTE' AS kaynak, ebat FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
 WHERE u.tenant_id='$TEN'::uuid AND u.aktif AND k.ebat IS NOT NULL
 GROUP BY 2 ORDER BY random() LIMIT 6;
SELECT 'SATIS' AS kaynak, ebat FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND ebat IS NOT NULL
 GROUP BY 2 ORDER BY random() LIMIT 6;

\echo ''
\echo '=== 6) KESISIM TESTI — kac (marka,ebat) ciftinde ORTAK? ==='
WITH l AS (SELECT DISTINCT u.marka, k.ebat
             FROM bi_fiyat_listesi_kalemler k
             JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
            WHERE u.tenant_id='$TEN'::uuid),
     s AS (SELECT DISTINCT marka, ebat FROM bi_satis_faturalari
            WHERE tenant_id='$TEN' AND ebat IS NOT NULL
              AND fatura_tarihi >= CURRENT_DATE-365)
SELECT (SELECT count(*) FROM l) AS liste_cift,
       (SELECT count(*) FROM s) AS satis_cift,
       (SELECT count(*) FROM l JOIN s USING (marka, ebat)) AS ORTAK;
SQL
