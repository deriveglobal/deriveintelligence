#!/usr/bin/env bash
# İKİ BULGU DOĞRULAMA: bi_marj_fact (taze+tutuyor mu) + bi_odeme_gecmisi (DSO kesin mi). OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_marj_fact — TAZELİK (min/max ay) + kategori dağılımı"
$PSQL -c "SELECT min(ay)::text, max(ay)::text, count(*) FROM bi_marj_fact WHERE tenant_id='$T';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT kategori, count(*), round(sum(ciro)/1e6,1) ciro_m FROM bi_marj_fact WHERE tenant_id='$T' GROUP BY kategori ORDER BY ciro_m DESC NULLS LAST;" 2>&1 | sed 's/^/  /'

hr "2. ÇAPRAZ — marj_fact ciro vs omurga ciro_lastik (son 6 kapanmış ay, aynı mı)"
$PSQL -c "
SELECT 'marj_fact_TBR+OTR' k, round(sum(ciro)/1e6,1) ciro_m FROM bi_marj_fact
  WHERE tenant_id='$T' AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' AND ay<date_trunc('month',CURRENT_DATE)
UNION ALL
SELECT 'marj_fact_HEPSI', round(sum(ciro)/1e6,1) FROM bi_marj_fact
  WHERE tenant_id='$T' AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' AND ay<date_trunc('month',CURRENT_DATE)
UNION ALL
SELECT 'omurga_ciro_lastik', round(sum(deger)/1e6,1) FROM bi_metrik_gecmis
  WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND boyut_tipi='sirket'
    AND donem>=date_trunc('month',CURRENT_DATE)-interval '6 month' AND donem<date_trunc('month',CURRENT_DATE);" 2>&1 | sed 's/^/  /'

hr "3. ÇAPRAZ — CONTINENTAL marj%% (marj_fact) son 6 ay vs drill'in dediği ~%9"
$PSQL -c "
SELECT round(100.0*sum(brut_kar)/nullif(sum(ciro),0),1) marj_pct_marjfact, round(sum(ciro)/1e6,1) ciro_m, round(sum(brut_kar)/1e6,1) brutkar_m
  FROM bi_marj_fact WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL'
    AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' AND ay<date_trunc('month',CURRENT_DATE);" 2>&1 | sed 's/^/  /'

hr "4. bi_odeme_gecmisi — TAZELİK + kapsam (odeme_tarihi dolu mu)"
$PSQL -c "SELECT min(fatura_tarihi)::text, max(fatura_tarihi)::text, max(odeme_tarihi)::text son_odeme,
                 count(*) toplam, count(*) FILTER (WHERE odeme_tarihi IS NOT NULL) odemeli,
                 round(100.0*count(*) FILTER (WHERE odeme_tarihi IS NOT NULL)/count(*)) kapsam_pct
          FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "5. KESİN DSO denemesi — ort tahsilat günü (odeme-fatura) vs snapshot DSO ~130"
$PSQL -c "
SELECT count(*) fatura, round(avg(odeme_tarihi-fatura_tarihi),1) ort_tahsilat_gun,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY (odeme_tarihi-fatura_tarihi))) medyan_gun,
       round(avg(gecikme_gun),1) ort_gecikme
  FROM bi_odeme_gecmisi
 WHERE tenant_id='$T'::uuid AND odeme_tarihi IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-interval '12 month';" 2>&1 | sed 's/^/  /'

hr "6. tahsilat türü dağılımı (nakit vs vadeli vs çek — vade çekmecesi zenginliği)"
$PSQL -c "SELECT tahsilat_turu, count(*), round(avg(odeme_tarihi-fatura_tarihi),1) ort_gun FROM bi_odeme_gecmisi
          WHERE tenant_id='$T'::uuid AND odeme_tarihi IS NOT NULL AND fatura_tarihi>=CURRENT_DATE-interval '12 month'
          GROUP BY tahsilat_turu ORDER BY 2 DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "BITTI — marj_fact güvenilir mi + odeme_gecmisi DSO'yu kesin veriyor mu, net."
