#!/usr/bin/env bash
# ALACAK KESİN — bi_odeme_gecmisi (customercollection) ile reconstruction 209M'yi ~%7'den iyi tutturuyor mu? OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. KAPSAM — odeme_tarihi doluluk + açık (tahsil edilmemiş) fatura da var mı?"
$PSQL -c "
SELECT count(*) satir, count(odeme_tarihi) odeme_dolu, count(DISTINCT fatura_no) fatura,
       min(fatura_tarihi)::text fat_ilk, max(fatura_tarihi)::text fat_son,
       min(odeme_tarihi)::text ode_ilk, max(odeme_tarihi)::text ode_son
  FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid;"
echo "  ⚠ odeme_dolu < satir ise açık faturalar da içeride (iyi). Hepsi doluysa sadece tahsil edilenler var."

hr "2. FATURA EVRENİ KIYAS — bi_odeme_gecmisi distinct fatura vs bi_satis_faturalari"
$PSQL -c "SELECT
  (SELECT count(DISTINCT fatura_no) FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid) odeme_gecmisi_fatura,
  (SELECT count(DISTINCT fatura_no) FROM bi_satis_faturalari WHERE tenant_id='$T') satis_fatura;"

hr "3. ⚠ BUGÜN KESİN — açık alacak = Σ(fatura − bugüne dek ödenen), fatura başına"
$PSQL -c "
WITH inv AS (SELECT fatura_no, max(fatura_tutari) tutar, min(fatura_tarihi) ftar
              FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid GROUP BY fatura_no),
     paid AS (SELECT fatura_no, sum(odenen_tutar) p FROM bi_odeme_gecmisi
               WHERE tenant_id='$T'::uuid AND (odeme_tarihi IS NULL OR odeme_tarihi<=CURRENT_DATE) GROUP BY fatura_no)
SELECT round(sum(GREATEST(i.tutar - COALESCE(p.p,0),0))/1e6,1) acik_alacak_kesin_m
  FROM inv i LEFT JOIN paid p USING(fatura_no) WHERE i.ftar <= CURRENT_DATE;"
$PSQL -c "SELECT round(sum(hesap_bakiyesi)/1e6,1) erp_gercek_m FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND COALESCE(musteri_mi,true);"
echo "  ⚠ kesin ~209M'ye çok yakınsa (eski %7'den iyi) → alacak/DSO geçmişi KESİN olur, güven=snapshot→exact."

hr "4. ⚠ GEÇMİŞ KESİN — çeyrek çeyrek açık alacak (kesin yöntem) vs eski recon"
for D in 2025-07-01 2025-10-01 2026-01-01 2026-04-01 2026-07-01; do
  V=$($PSQL -tAc "
    WITH inv AS (SELECT fatura_no, max(fatura_tutari) tutar, min(fatura_tarihi) ftar
                  FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid GROUP BY fatura_no),
         paid AS (SELECT fatura_no, sum(odenen_tutar) p FROM bi_odeme_gecmisi
                   WHERE tenant_id='$T'::uuid AND odeme_tarihi < '$D' GROUP BY fatura_no)
    SELECT round(sum(GREATEST(i.tutar - COALESCE(p.p,0),0))/1e6,1)
      FROM inv i LEFT JOIN paid p USING(fatura_no) WHERE i.ftar < '$D'" | tr -d '[:space:]')
  printf "    %s : ~%s M (kesin)\n" "$D" "$V"
done
echo "  ⚠ Eski recon: 128/135/107/97/230. Kesin yöntem daha yumuşak/tutarlıysa DSO geçmişini yükseltiriz."

hr "BITTI — bu veri alacak/DSO'yu yaklaşıktan kesine çıkarabilir. Sonuç iyiyse omurgayı yükseltiriz."
