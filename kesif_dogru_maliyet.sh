#!/usr/bin/env bash
# DOĞRU MALİYET BAZI — son6ay ağırlıklı (ham) vs son6ay toplu-alış (temiz: adet≥5, tutar>0). Kesin marj. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ÖRNEK SKU (CNT-512627) — dört maliyet bazı yan yana"
$PSQL -c "
SELECT
  round((SELECT sum(giris_tutari)/NULLIF(sum(giris),0) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='CNT-512627' AND giris>0)) tum_gecmis,
  round((SELECT sum(giris_tutari)/NULLIF(sum(giris),0) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='CNT-512627' AND giris>0 AND belge_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month')) son6ay_ham,
  round((SELECT sum(giris_tutari)/NULLIF(sum(giris),0) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='CNT-512627' AND giris>=5 AND giris_tutari>0 AND belge_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month')) son6ay_toplu_temiz,
  round((SELECT giris_tutari/NULLIF(giris,0) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='CNT-512627' AND giris>0 ORDER BY belge_tarihi DESC LIMIT 1)) son_alis_tek;" 2>&1 | sed 's/^/  /'

hr "2. CONTINENTAL TOPLAM MARJ — dört bazla (son 6 ay satış)"
$PSQL -c "
WITH m0 AS (SELECT date_trunc('month',CURRENT_DATE)::date d),
tg AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu),
s6h AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 AND belge_tarihi>=(SELECT d FROM m0)-interval '6 month' GROUP BY kalem_kodu),
s6t AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 AND belge_tarihi>=(SELECT d FROM m0)-interval '6 month' GROUP BY kalem_kodu),
sat AS (SELECT kalem_kodu, sum(satir_tutar) ciro, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0 AND fatura_tarihi>=(SELECT d FROM m0)-interval '6 month' AND fatura_tarihi<(SELECT d FROM m0) GROUP BY kalem_kodu)
SELECT round(sum(ciro)/1e6,1) ciro_m,
       round(100*(sum(ciro)-sum(adet*tg.c))/NULLIF(sum(ciro),0),1)  marj_tum_gecmis,
       round(100*(sum(ciro)-sum(adet*s6h.c))/NULLIF(sum(ciro),0),1) marj_son6ay_ham,
       round(100*(sum(ciro)-sum(adet*COALESCE(s6t.c,s6h.c,tg.c)))/NULLIF(sum(ciro),0),1) marj_son6ay_temiz
  FROM sat LEFT JOIN tg USING(kalem_kodu) LEFT JOIN s6h USING(kalem_kodu) LEFT JOIN s6t USING(kalem_kodu);" 2>&1 | sed 's/^/  /'

hr "3. TÜM MARKALAR — mevcut (tüm-geçmiş) vs son6ay-temiz marj (şişme markaya göre ne kadar)"
$PSQL -c "
WITH m0 AS (SELECT date_trunc('month',CURRENT_DATE)::date d),
tg AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu),
s6t AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 AND belge_tarihi>=(SELECT d FROM m0)-interval '6 month' GROUP BY kalem_kodu),
sat AS (SELECT upper(marka) marka, kalem_kodu, sum(satir_tutar) ciro, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id='$T' AND ebat IS NOT NULL AND miktar>0 AND fatura_tarihi>=(SELECT d FROM m0)-interval '6 month' AND fatura_tarihi<(SELECT d FROM m0) GROUP BY 1,2)
SELECT sat.marka, round(sum(ciro)/1e6,1) ciro_m,
       round(100*(sum(ciro)-sum(adet*tg.c))/NULLIF(sum(ciro),0),1) marj_mevcut,
       round(100*(sum(ciro)-sum(adet*COALESCE(s6t.c,tg.c)))/NULLIF(sum(ciro),0),1) marj_dogru_son6ay
  FROM sat LEFT JOIN tg USING(kalem_kodu) LEFT JOIN s6t USING(kalem_kodu)
 GROUP BY sat.marka HAVING sum(ciro)>10000000 ORDER BY ciro_m DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "BITTI — doğru maliyet bazı + hangi markanın marjı ne kadar şişikti, net."
