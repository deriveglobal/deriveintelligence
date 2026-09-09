#!/usr/bin/env bash
# SEBEP-ARAŞTIRICI İLK GEÇİŞ — CONTINENTAL kâr sızıntısı: çekmeceleri aç, kanıtla açıkla ya da "yok". OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }
KM="WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) bm FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu)"

hr "0. ÖZET — CONTINENTAL önceki 6ay vs son 6ay (ciro, marj%, maliyet=bugünkü ağ.ort)"
$PSQL -c "
$KM, c AS (
  SELECT s.kalem_kodu, max(km.bm) cost,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)-interval '6 month') ciro_o,
    sum(s.miktar)     FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)-interval '6 month') qty_o,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)) ciro_s,
    sum(s.miktar)     FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)) qty_s
  FROM bi_satis_faturalari s JOIN km ON km.kalem_kodu=s.kalem_kodu
  WHERE s.tenant_id='$T' AND upper(s.marka)='CONTINENTAL' AND s.ebat IS NOT NULL AND s.miktar>0
    AND s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' GROUP BY s.kalem_kodu)
SELECT round(sum(ciro_o)/1e6,1) ciro_o_m, round(100*(sum(ciro_o)-sum(qty_o*cost))/nullif(sum(ciro_o),0),1) marj_o_pct,
       round(sum(ciro_s)/1e6,1) ciro_s_m, round(100*(sum(ciro_s)-sum(qty_s*cost))/nullif(sum(ciro_s),0),1) marj_s_pct
  FROM c;" 2>&1 | sed 's/^/  /'

hr "1. FİYAT çekmecesi — hangi SKU'da fiyat düştü + marj kaybı (top 8, ağırlıklı)"
$PSQL -c "
$KM, c AS (
  SELECT s.kalem_kodu, left(max(s.kalem_tanimi),20) tanim, max(km.bm) cost,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)-interval '6 month')/NULLIF(sum(s.miktar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)-interval '6 month'),0) fiyat_o,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE))/NULLIF(sum(s.miktar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)),0) fiyat_s,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)) ciro_s
  FROM bi_satis_faturalari s JOIN km ON km.kalem_kodu=s.kalem_kodu
  WHERE s.tenant_id='$T' AND upper(s.marka)='CONTINENTAL' AND s.ebat IS NOT NULL AND s.miktar>0
    AND s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' GROUP BY s.kalem_kodu)
SELECT tanim, round(fiyat_o) fiyat_o, round(fiyat_s) fiyat_s, round(100*(fiyat_s-fiyat_o)/nullif(fiyat_o,0)) fiyat_degis_pct,
       round(100*(1-cost/nullif(fiyat_o,0))) marj_o, round(100*(1-cost/nullif(fiyat_s,0))) marj_s, round(ciro_s/1e6,2) ciro_s_m
  FROM c WHERE ciro_s>500000 AND fiyat_o IS NOT NULL AND fiyat_s IS NOT NULL
  ORDER BY (100*(1-cost/nullif(fiyat_o,0)) - 100*(1-cost/nullif(fiyat_s,0)))*ciro_s DESC NULLS LAST LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "2. MIX çekmecesi — düşük-marjlı SKU payı arttı mı (yüksek≥%20 vs düşük<%20 ciro payı)"
$PSQL -c "
$KM, c AS (
  SELECT s.kalem_kodu, max(km.bm) cost,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)-interval '6 month') ciro_o,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)) ciro_s,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE))/NULLIF(sum(s.miktar) FILTER (WHERE s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'  AND s.fatura_tarihi<date_trunc('month',CURRENT_DATE)),0) fiyat_s
  FROM bi_satis_faturalari s JOIN km ON km.kalem_kodu=s.kalem_kodu
  WHERE s.tenant_id='$T' AND upper(s.marka)='CONTINENTAL' AND s.ebat IS NOT NULL AND s.miktar>0 AND s.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' GROUP BY s.kalem_kodu)
SELECT CASE WHEN (1-cost/nullif(fiyat_s,0))>=0.20 THEN 'yuksek_marj' ELSE 'dusuk_marj' END grup,
       round(sum(ciro_o)/1e6,1) ciro_o_m, round(sum(ciro_s)/1e6,1) ciro_s_m
  FROM c WHERE fiyat_s IS NOT NULL GROUP BY 1 ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "3. PİYASA çekmecesi — rakip_fiyat_gecmis'te CONTINENTAL var mı + fiyat trendi"
$PSQL -c "SELECT to_char(date_trunc('month',gecerli_tarih),'YYYY-MM') ay, count(*), round(avg(fiyat)) ort_piyasa_fiyat
          FROM bi_rakip_fiyat_gecmis WHERE tenant_id='$T' AND marka ILIKE '%continental%' GROUP BY 1 ORDER BY 1 DESC LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "4. İADE çekmecesi — CONTINENTAL iade (önceki vs son 6 ay)"
$PSQL -c "SELECT round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE)-interval '6 month')/1e6,2) iade_onceki_m,
                 round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month')/1e6,2) iade_son_m
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND miktar<0;" 2>&1 | sed 's/^/  /'

hr "5. ZİYARET çekmecesi — notlarda continental/fiyat/rakip (son 6 ay, serbest metin)"
$PSQL -c "SELECT ziyaret_tarihi, left(notlar,110) not
          FROM saha_ziyaret WHERE tenant_id='$T'::uuid AND ziyaret_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month'
            AND (notlar ILIKE '%continental%' OR notlar ILIKE '%fiyat%' OR notlar ILIKE '%rakip%' OR detay::text ILIKE '%continental%')
          ORDER BY ziyaret_tarihi DESC LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "BITTI — çekmeceler açıldı. Sebep fiyat mı, mix mi, piyasa mı, ziyaret mi — yoksa 'açıklama yok' mu?"
