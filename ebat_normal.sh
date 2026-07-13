#!/usr/bin/env bash
# EBAT_NORM — liste<->satis eslesmesini onar. UC ANAHTAR ADAYI test ediliyor.
#
# ⚠ BULUNAN: liste 1.210 (marka,ebat) cifti, satis 1.511, ORTAK sadece 278 (%23).
#   Fiyat listesinin DORTTE UCU olu. Bu KUPUN degil, CANLIDAKI FIYAT MODULUNUN de sorunu.
#
# ⚠ SEBEP: format. Liste '205/65 R 15 XL' / '205/50R17XL', satis '215/55R18'.
#
# HANGI ANAHTAR? Uydurmadan olcuyoruz:
#   A) urun_kodu = kalem_kodu   -> SKU. EN IYISI. Varsa fuzzy'ye gerek yok.
#   B) ebat_norm                -> bosluk sil, buyut, XL/RF ekini ayikla
#   C) mevcut ham ebat          -> %23 (taban cizgi)
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

$PSQL -v ON_ERROR_STOP=1 <<'SQL'
-- ⚠ NORMALIZER. C (ticari) KORUNUR — anlamli. XL/RF/RFT ATILIR — ayni fiziksel ebat.
CREATE OR REPLACE FUNCTION bi_ebat_norm(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN m[1] IS NULL THEN NULL
         ELSE m[1] || '/' || m[2] || 'R' || m[3] || COALESCE(m[4],'')
         END
  FROM regexp_match(
         upper(regexp_replace(COALESCE(p,''), '\s+', '', 'g')),
         '^([0-9]{3})/([0-9]{2})[ZR/.-]*R?([0-9]{2})(C)?'
       ) AS m;
$$;
SQL
echo "  ✅ bi_ebat_norm()"

$PSQL <<SQL
SET app.current_tenant_id = '$TEN';

\echo ''
\echo '=== A) SKU ANAHTARI: liste.urun_kodu = satis.kalem_kodu ? ==='
SELECT count(*) FILTER (WHERE k.urun_kodu IS NOT NULL) AS liste_urun_kodu_dolu,
       count(*) AS liste_kalem
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
 WHERE u.tenant_id='$TEN'::uuid;

WITH s AS (SELECT DISTINCT kalem_kodu FROM bi_satis_faturalari
            WHERE tenant_id='$TEN' AND ebat IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-365)
SELECT count(DISTINCT k.urun_kodu) AS liste_sku,
       count(DISTINCT k.urun_kodu) FILTER (WHERE s.kalem_kodu IS NOT NULL) AS satisla_eslesen
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
  LEFT JOIN s ON s.kalem_kodu = k.urun_kodu
 WHERE u.tenant_id='$TEN'::uuid;

\echo ''
\echo '=== B) EBAT_NORM ANAHTARI — orneklerle ==='
SELECT k.ebat AS liste_ham, bi_ebat_norm(k.ebat) AS liste_norm
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
 WHERE u.tenant_id='$TEN'::uuid GROUP BY 1,2 ORDER BY random() LIMIT 8;

\echo ''
\echo '=== C) ⚠⚠ KESISIM: ham vs normalize (marka da buyutuluyor) ==='
WITH l AS (SELECT DISTINCT upper(u.marka) marka, k.ebat AS ham, bi_ebat_norm(k.ebat) AS nrm
             FROM bi_fiyat_listesi_kalemler k
             JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
            WHERE u.tenant_id='$TEN'::uuid),
     s AS (SELECT DISTINCT upper(marka) marka, ebat AS ham, bi_ebat_norm(ebat) AS nrm,
                  sum(satir_tutar) OVER () AS dummy
             FROM bi_satis_faturalari
            WHERE tenant_id='$TEN' AND ebat IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-365)
SELECT (SELECT count(*) FROM l JOIN s ON s.marka=l.marka AND s.ham=l.ham)   AS ham_eslesme,
       (SELECT count(*) FROM l JOIN s ON s.marka=l.marka AND s.nrm=l.nrm
          WHERE l.nrm IS NOT NULL)                                          AS norm_eslesme,
       (SELECT count(*) FROM l WHERE nrm IS NULL)                           AS liste_cozulemeyen,
       (SELECT count(*) FROM s WHERE nrm IS NULL)                           AS satis_cozulemeyen;

\echo ''
\echo '=== D) ⚠⚠ ASIL SORU: CIRONUN YUZDE KACI FIYATLANABILIYOR? ==='
WITH l AS (SELECT DISTINCT upper(u.marka) marka, bi_ebat_norm(k.ebat) AS nrm
             FROM bi_fiyat_listesi_kalemler k
             JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
            WHERE u.tenant_id='$TEN'::uuid AND bi_ebat_norm(k.ebat) IS NOT NULL)
SELECT round(sum(f.satir_tutar)/1e6,1) AS lastik_ciro_M,
       round(100.0*sum(f.satir_tutar) FILTER (WHERE l.marka IS NOT NULL)/sum(f.satir_tutar)) AS liste_kapsam_pct,
       round(sum(f.satir_tutar) FILTER (WHERE l.marka IS NOT NULL)/1e6,1) AS bayilik_ciro_M
  FROM bi_satis_faturalari f
  LEFT JOIN l ON l.marka=upper(f.marka) AND l.nrm=bi_ebat_norm(f.ebat)
 WHERE f.tenant_id='$TEN' AND f.miktar>0 AND f.ebat IS NOT NULL
   AND f.fatura_tarihi>=CURRENT_DATE-365
   AND COALESCE(f.kategori,'') NOT IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
   AND COALESCE(f.satis_kanali,'') NOT ILIKE '%YANSIT%';

\echo ''
\echo '=== E) ⚠ TESVIK JOIN — marka BUYUK/kucuk harf. Duzelince eslesir mi? ==='
SELECT upper(u.marka) AS liste, upper(tt.marka) AS tesvik, tt.segment, tt.kanal,
       tt.fatura_alti_pct + COALESCE(tt.donem_primi_pct,0)
     + COALESCE(tt.sellout_primi_pct,0) AS toplam_tesvik_pct
  FROM bi_fiyat_listesi_uploads u
  JOIN bi_tedarikci_tesvik tt
    ON upper(tt.marka)=upper(u.marka) AND tt.tenant_id=u.tenant_id
 WHERE u.tenant_id='$TEN'::uuid AND u.aktif
 GROUP BY 1,2,3,4,5 ORDER BY 1,3,4;

\echo ''
\echo '=== F) ⚠ KANAL ESLEMESI — tesvik toptan/perakende, satista ne var? ==='
SELECT satis_kanali, round(sum(satir_tutar)/1e6,1) AS ciro_M
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND miktar>0 AND ebat IS NOT NULL
   AND upper(marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR')
   AND fatura_tarihi>=CURRENT_DATE-365
 GROUP BY 1 ORDER BY 2 DESC;
SQL
