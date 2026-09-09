#!/usr/bin/env bash
# MARJ KÖPRÜSÜ (SKU-seviyesi) — düşüşü fiyat + maliyet + hacim/mix TL olarak ayrıştır. Fatih ilkesi. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "CONTINENTAL MARJ KÖPRÜSÜ — önceki 6ay (O) → son 6ay (S), dönem-maliyetli"
$PSQL -c "
WITH m0 AS (SELECT date_trunc('month',CURRENT_DATE)::date d),
allbulk AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 GROUP BY kalem_kodu),
bulkO AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 AND belge_tarihi>=(SELECT d FROM m0)-interval '18 month' AND belge_tarihi<(SELECT d FROM m0)-interval '6 month' GROUP BY kalem_kodu),
bulkS AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 AND belge_tarihi>=(SELECT d FROM m0)-interval '12 month' AND belge_tarihi<(SELECT d FROM m0) GROUP BY kalem_kodu),
sku AS (
  SELECT s.kalem_kodu,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=(SELECT d FROM m0)-interval '12 month' AND s.fatura_tarihi<(SELECT d FROM m0)-interval '6 month') ciro_o,
    sum(s.miktar)     FILTER (WHERE s.fatura_tarihi>=(SELECT d FROM m0)-interval '12 month' AND s.fatura_tarihi<(SELECT d FROM m0)-interval '6 month') qo,
    sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=(SELECT d FROM m0)-interval '6 month' AND s.fatura_tarihi<(SELECT d FROM m0)) ciro_s,
    sum(s.miktar)     FILTER (WHERE s.fatura_tarihi>=(SELECT d FROM m0)-interval '6 month' AND s.fatura_tarihi<(SELECT d FROM m0)) qs,
    COALESCE(max(bo.c),max(ab.c)) ko, COALESCE(max(bs.c),max(ab.c)) ks
  FROM bi_satis_faturalari s
    LEFT JOIN bulkO bo ON bo.kalem_kodu=s.kalem_kodu LEFT JOIN bulkS bs ON bs.kalem_kodu=s.kalem_kodu LEFT JOIN allbulk ab ON ab.kalem_kodu=s.kalem_kodu
  WHERE s.tenant_id='$T' AND upper(s.marka)='CONTINENTAL' AND s.ebat IS NOT NULL AND s.miktar>0
    AND s.fatura_tarihi>=(SELECT d FROM m0)-interval '12 month' AND s.fatura_tarihi<(SELECT d FROM m0)
  GROUP BY s.kalem_kodu)
SELECT
  round(sum(COALESCE(ciro_o,0)-COALESCE(qo,0)*ko)/1e6,2)                                    marj_O_m,
  round(sum(COALESCE(ciro_s,0)-COALESCE(qs,0)*ks)/1e6,2)                                    marj_S_m,
  round((sum(COALESCE(ciro_s,0)-COALESCE(qs,0)*ks)-sum(COALESCE(ciro_o,0)-COALESCE(qo,0)*ko))/1e6,2) degisim_m,
  round(sum(CASE WHEN qo>0 AND qs>0 THEN qs*((ciro_s/qs)-(ciro_o/qo)) END)/1e6,2)           fiyat_etkisi_m,
  round(sum(CASE WHEN qo>0 AND qs>0 THEN qs*(ko-ks) END)/1e6,2)                             maliyet_etkisi_m
  FROM sku;" 2>&1 | sed 's/^/  /'

hr "AÇIKLAMA"
echo "  degisim = marj_S − marj_O (mutlak marj TL değişimi)"
echo "  fiyat_etkisi   = Σ qs×(fiyat_s − fiyat_o)   [ortak SKU'lar, fiyat oynaması]"
echo "  maliyet_etkisi = Σ qs×(maliyet_o − maliyet_s) [ortak SKU'lar, maliyet oynaması]"
echo "  hacim/mix      = degisim − fiyat − maliyet   [artık: yeni/düşen SKU + sepet kayması]"

hr "BITTI — köprü: kâr değişimi fiyat + maliyet + hacim/mix olarak ayrıştı. Uygulama bunu söyler."
