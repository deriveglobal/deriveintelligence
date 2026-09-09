#!/usr/bin/env bash
# ZAMANA-ENDEKSLİ MALİYET — her satış kendi ayının maliyetiyle. Herhangi pencere + trend doğru. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

# dönem-eşleşmeli maliyet: satışın ayı için, o ayı bitiren izleyen 6 ayın toplu-alış ağ.ort (adet>=5, tutar>0)
COST="(SELECT sum(h.giris_tutari)/NULLIF(sum(h.giris),0) FROM bi_stok_hareket h
        WHERE h.tenant_id='$T'::uuid AND h.kalem_kodu=sa.kalem_kodu AND h.giris>=5 AND h.giris_tutari>0
          AND h.belge_tarihi >= sa.ay - interval '6 month' AND h.belge_tarihi < sa.ay + interval '1 month')"

hr "1. CONTINENTAL — dönem-eşleşmeli marj: 6 ay vs 12 ay (her satış kendi ayı maliyeti + fallback)"
$PSQL -c "
WITH satay AS (
  SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, sum(satir_tutar) ciro, sum(miktar) adet
    FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0
      AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE)
    GROUP BY 1,2),
tumbulk AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 GROUP BY kalem_kodu),
m AS (SELECT sa.*, COALESCE($COST, tb.c) cost_asof, ($COST IS NOT NULL) eslesti FROM satay sa LEFT JOIN tumbulk tb USING(kalem_kodu))
SELECT '6 ay' pencere, round(sum(ciro)/1e6,1) ciro_m, round(100*(sum(ciro)-sum(adet*cost_asof))/NULLIF(sum(ciro),0),1) marj_donem_eslesmeli,
       round(100*sum(ciro) FILTER (WHERE eslesti)/NULLIF(sum(ciro),0)) kapsam_pct
  FROM m WHERE ay>=date_trunc('month',CURRENT_DATE)-interval '6 month'
UNION ALL
SELECT '12 ay', round(sum(ciro)/1e6,1), round(100*(sum(ciro)-sum(adet*cost_asof))/NULLIF(sum(ciro),0),1),
       round(100*sum(ciro) FILTER (WHERE eslesti)/NULLIF(sum(ciro),0))
  FROM m;" 2>&1 | sed 's/^/  /'

hr "2. AYLIK MARJ TRENDİ — dönem-eşleşmeli (her ay kendi maliyeti; sabit-baz gizlerdi)"
$PSQL -c "
WITH satay AS (
  SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, sum(satir_tutar) ciro, sum(miktar) adet
    FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0
      AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE)
    GROUP BY 1,2),
tumbulk AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 GROUP BY kalem_kodu),
m AS (SELECT sa.*, COALESCE($COST, tb.c) cost_asof FROM satay sa LEFT JOIN tumbulk tb USING(kalem_kodu))
SELECT to_char(ay,'YYYY-MM') ay, round(sum(ciro)/1e6,1) ciro_m, round(100*(sum(ciro)-sum(adet*cost_asof))/NULLIF(sum(ciro),0),1) marj_pct
  FROM m GROUP BY ay ORDER BY ay;" 2>&1 | sed 's/^/  /'

hr "3. KARŞILAŞTIRMA — aynı 6 ay: dönem-eşleşmeli vs sabit-son6ay vs tüm-geçmiş"
$PSQL -c "
WITH satay AS (SELECT kalem_kodu, date_trunc('month',fatura_tarihi)::date ay, sum(satir_tutar) ciro, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0 AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE) GROUP BY 1,2),
tg AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu),
fix6 AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 AND belge_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY kalem_kodu),
tumbulk AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>=5 AND giris_tutari>0 GROUP BY kalem_kodu),
m AS (SELECT sa.*, COALESCE($COST, tb.c) cost_donem, tg.c cost_tg, COALESCE(fix6.c,tb.c) cost_fix6 FROM satay sa LEFT JOIN tg USING(kalem_kodu) LEFT JOIN fix6 USING(kalem_kodu) LEFT JOIN tumbulk tb USING(kalem_kodu))
SELECT round(100*(sum(ciro)-sum(adet*cost_tg))/NULLIF(sum(ciro),0),1) marj_tum_gecmis,
       round(100*(sum(ciro)-sum(adet*cost_fix6))/NULLIF(sum(ciro),0),1) marj_sabit_son6ay,
       round(100*(sum(ciro)-sum(adet*cost_donem))/NULLIF(sum(ciro),0),1) marj_donem_eslesmeli
  FROM m;" 2>&1 | sed 's/^/  /'

hr "BITTI — dönem-eşleşmeli maliyet herhangi pencerede + trendde doğru; sabit-baz özel hal."
