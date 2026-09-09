#!/usr/bin/env bash
# NEDEN KÂR DÜŞTÜ — CONTINENTAL: maliyet mi fiyattan hızlı arttı (enflasyon sıkışması) yoksa mix mi. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }
COST="(SELECT sum(h.giris_tutari)/NULLIF(sum(h.giris),0) FROM bi_stok_hareket h WHERE h.tenant_id='$T'::uuid AND h.kalem_kodu=sa.kalem_kodu AND h.giris>=5 AND h.giris_tutari>0 AND h.belge_tarihi >= sa.ay - interval '6 month' AND h.belge_tarihi < sa.ay + interval '1 month')"

hr "1. AYLIK — CONTINENTAL ort satış fiyatı vs dönem-maliyeti vs marj% (maliyet fiyatı yakalıyor mu)"
$PSQL -c "
WITH satay AS (SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, sum(satir_tutar) ciro, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0 AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE) GROUP BY 1,2),
tb AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 GROUP BY kalem_kodu),
m AS (SELECT sa.*, COALESCE($COST, tb.c) cost FROM satay sa LEFT JOIN tb USING(kalem_kodu))
SELECT to_char(ay,'YYYY-MM') ay, round(sum(ciro)/NULLIF(sum(adet),0)) ort_fiyat, round(sum(adet*cost)/NULLIF(sum(adet),0)) ort_maliyet,
       round(100*(sum(ciro)-sum(adet*cost))/NULLIF(sum(ciro),0),1) marj_pct
  FROM m GROUP BY ay ORDER BY ay;" 2>&1 | sed 's/^/  /'

hr "2. HINT — ilk 3 ay vs son 3 ay: fiyat %kaç arttı, maliyet %kaç arttı (hangisi hızlı)"
$PSQL -c "
WITH satay AS (SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, sum(satir_tutar) ciro, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0 AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE) GROUP BY 1,2),
tb AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 GROUP BY kalem_kodu),
m AS (SELECT sa.*, COALESCE($COST, tb.c) cost FROM satay sa LEFT JOIN tb USING(kalem_kodu)),
ilk AS (SELECT sum(ciro)/NULLIF(sum(adet),0) f, sum(adet*cost)/NULLIF(sum(adet),0) c FROM m WHERE ay< (SELECT min(ay) FROM m)+interval '3 month'),
son AS (SELECT sum(ciro)/NULLIF(sum(adet),0) f, sum(adet*cost)/NULLIF(sum(adet),0) c FROM m WHERE ay>= (SELECT max(ay) FROM m)-interval '2 month')
SELECT round(100*(son.f-ilk.f)/NULLIF(ilk.f,0)) fiyat_artis_pct, round(100*(son.c-ilk.c)/NULLIF(ilk.c,0)) maliyet_artis_pct,
       round(100*(son.f-ilk.f)/NULLIF(ilk.f,0)) - round(100*(son.c-ilk.c)/NULLIF(ilk.c,0)) fark_puan
  FROM ilk, son;" 2>&1 | sed 's/^/  /'

hr "3. MIX kontrolü — düşük-marj SKU payı ilk 3 ay vs son 3 ay (dönem-maliyetle)"
$PSQL -c "
WITH satay AS (SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, sum(satir_tutar) ciro, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0 AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE) GROUP BY 1,2),
tb AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 GROUP BY kalem_kodu),
m AS (SELECT sa.*, COALESCE($COST, tb.c) cost, CASE WHEN (1-COALESCE($COST,tb.c)/NULLIF(ciro/NULLIF(adet,0),0))<0.15 THEN 'dusuk' ELSE 'yuksek' END grup FROM satay sa LEFT JOIN tb USING(kalem_kodu))
SELECT CASE WHEN ay<(SELECT min(ay) FROM m)+interval '3 month' THEN 'ilk3ay' WHEN ay>=(SELECT max(ay) FROM m)-interval '2 month' THEN 'son3ay' END donem, grup, round(sum(ciro)/1e6,1) ciro_m
  FROM m WHERE ay<(SELECT min(ay) FROM m)+interval '3 month' OR ay>=(SELECT max(ay) FROM m)-interval '2 month'
  GROUP BY 1,2 ORDER BY 1,2;" 2>&1 | sed 's/^/  /'

hr "BITTI — hint: maliyet mi fiyatı geçti (enflasyon sıkışması) yoksa mix mi. Uygulama bunu söyleyebilir."
