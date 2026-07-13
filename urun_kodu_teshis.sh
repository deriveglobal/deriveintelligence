#!/usr/bin/env bash
# ⚠ urun_kodu SATISTA OLMALI (Fatih). 2571 liste SKU -> sadece 95 eslesti.
#   Demek ki FORMAT farkli. Yan yana koyup GORECEGIZ. Tahmin yok.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

$PSQL <<SQL
SET app.current_tenant_id = '$TEN';

\echo '=== 1) LISTE urun_kodu — ham ornekler + uzunluk dagilimi ==='
SELECT upper(u.marka) AS marka, k.urun_kodu, length(k.urun_kodu) AS uzunluk, k.ebat, k.desen
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
 WHERE u.tenant_id='$TEN'::uuid
 ORDER BY random() LIMIT 12;

\echo ''
\echo '=== 2) SATIS kalem_kodu — ayni markalarda ham ornekler ==='
SELECT upper(marka) AS marka, kalem_kodu, length(kalem_kodu) AS uzunluk, ebat,
       left(kalem_tanimi,40) AS tanim
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND ebat IS NOT NULL
   AND upper(marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR')
   AND fatura_tarihi >= CURRENT_DATE-365
 GROUP BY 1,2,3,4,5 ORDER BY random() LIMIT 12;

\echo ''
\echo '=== 3) UZUNLUK DAGILIMI — iki tarafta ==='
SELECT 'LISTE' AS taraf, length(k.urun_kodu) AS uzunluk, count(*)
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
 WHERE u.tenant_id='$TEN'::uuid GROUP BY 1,2
UNION ALL
SELECT 'SATIS', length(kalem_kodu), count(DISTINCT kalem_kodu)
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND ebat IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-365
 GROUP BY 1,2 ORDER BY 1,2;

\echo ''
\echo '=== 4) ⚠ ESLESEN 95 NASIL GORUNUYOR? (dogru format bu) ==='
WITH s AS (SELECT DISTINCT kalem_kodu, marka, ebat FROM bi_satis_faturalari
            WHERE tenant_id='$TEN' AND fatura_tarihi>=CURRENT_DATE-365)
SELECT k.urun_kodu, upper(u.marka) AS liste_marka, k.ebat AS liste_ebat,
       s.marka AS satis_marka, s.ebat AS satis_ebat
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
  JOIN s ON s.kalem_kodu = k.urun_kodu
 WHERE u.tenant_id='$TEN'::uuid LIMIT 8;

\echo ''
\echo '=== 5) ⚠ KIRPILMIS/DOLGULU MU? — normalize edip tekrar dene ==='
WITH l AS (
  SELECT DISTINCT k.urun_kodu AS ham,
         upper(regexp_replace(k.urun_kodu, '[^A-Za-z0-9]', '', 'g')) AS sade,
         ltrim(regexp_replace(k.urun_kodu,'[^0-9]','','g'),'0')       AS sadece_rakam
    FROM bi_fiyat_listesi_kalemler k
    JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
   WHERE u.tenant_id='$TEN'::uuid AND k.urun_kodu IS NOT NULL),
s AS (
  SELECT DISTINCT kalem_kodu AS ham,
         upper(regexp_replace(kalem_kodu, '[^A-Za-z0-9]', '', 'g')) AS sade,
         ltrim(regexp_replace(kalem_kodu,'[^0-9]','','g'),'0')       AS sadece_rakam
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-365)
SELECT (SELECT count(*) FROM l) AS liste_sku,
       (SELECT count(*) FROM l JOIN s ON s.ham=l.ham)                  AS ham_eslesme,
       (SELECT count(*) FROM l JOIN s ON s.sade=l.sade)                AS sade_eslesme,
       (SELECT count(*) FROM l JOIN s ON s.sadece_rakam=l.sadece_rakam
          WHERE length(l.sadece_rakam)>4)                              AS rakam_eslesme,
       (SELECT count(*) FROM l JOIN s ON s.sade LIKE '%'||l.sade||'%'
          WHERE length(l.sade)>5)                                      AS icinde_gecen;

\echo ''
\echo '=== 6) ⚠ TEDARIKCI FATURASINDA urun_kodu VAR MI? (alis tarafi kopru olabilir) ==='
SELECT kalem_kodu, marka, left(kalem_tanimi,45) AS tanim, count(*)
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND upper(marka) IN ('BRIDGESTONE','LASSA','CONTINENTAL')
 GROUP BY 1,2,3 ORDER BY random() LIMIT 8;
SQL
