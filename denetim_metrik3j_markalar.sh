#!/usr/bin/env bash
# METRIK 3J — HANGI MARKALAR kirik? marka marka fatura vs ERP giris vs kup. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. MARKA MARKA — fatura / ERP giris / kup cikis + giris÷fatura orani"
$PSQL -c "
WITH sa AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric f
              FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0
             ORDER BY kalem_kodu, fatura_tarihi DESC),
gh AS (SELECT kalem_kodu,
              sum(giris_tutari)/nullif(sum(giris),0) giris_birim,
              sum(cikis_tutari)/nullif(sum(cikis),0) cikis_birim
         FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1)
SELECT COALESCE(s.marka,'(bos)') marka,
       round(sum(s.adet)) adet,
       round(sum(s.adet*sa.f)/1e6,1)          fatura_m,
       round(sum(s.adet*gh.giris_birim)/1e6,1) erp_giris_m,
       round(sum(s.adet*gh.cikis_birim)/1e6,1) kup_cikis_m,
       round(sum(s.adet*gh.giris_birim)/nullif(sum(s.adet*sa.f),0),2) giris_fatura_oran
  FROM bi_stok_anlik s
  LEFT JOIN sa ON sa.kalem_kodu=s.kalem_kodu
  LEFT JOIN gh ON gh.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid
 GROUP BY 1 ORDER BY 3 DESC NULLS LAST;"
echo "  ⚠ oran ~1: temiz (ERP faturaya yakin stoga aliyor). oran >1.4: KIRIK (ERP fazla yuksek aliyor)."

hr "2. ⚠ OZET — kirik (oran>1.4) vs temiz markalar toplam stok degeri (fatura bazli)"
$PSQL -c "
WITH sa AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric f FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0 ORDER BY kalem_kodu, fatura_tarihi DESC),
gh AS (SELECT kalem_kodu, sum(giris_tutari)/nullif(sum(giris),0) g, sum(cikis_tutari)/nullif(sum(cikis),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1),
m AS (SELECT s.marka, sum(s.adet*sa.f) fatura, sum(s.adet*gh.g) giris
        FROM bi_stok_anlik s LEFT JOIN sa ON sa.kalem_kodu=s.kalem_kodu LEFT JOIN gh ON gh.kalem_kodu=s.kalem_kodu
       WHERE s.tenant_id='$T'::uuid GROUP BY 1)
SELECT CASE WHEN giris/nullif(fatura,0) > 1.4 THEN 'KIRIK (>1.4x)' ELSE 'temiz' END durum,
       count(*) marka, round(sum(fatura)/1e6,1) fatura_m, round(sum(giris)/1e6,1) giris_m
  FROM m WHERE fatura>0 GROUP BY 1 ORDER BY 3 DESC;"
echo "  ⚠ 'KIRIK' grubun fatura_m'si, belirsizligin BUYUKLUGU (stok degerinin ne kadari suphede)."

hr "BITTI"
