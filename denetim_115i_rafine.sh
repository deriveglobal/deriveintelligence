#!/usr/bin/env bash
# DENETIM_115I — %7 farki kovala: kredili-only, iade, timing. 209'a yaklasiyor mu? OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ACIK faturalarin KIRILIMI — nakit/kredi, pozitif/negatif"
$PSQL -c "
WITH inv AS (
  SELECT fatura_no, musteri_kodu, min(fatura_tarihi) ft, max(odeme_kosulu) ok, sum(satir_tutar) tutar
    FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2),
paid AS (SELECT DISTINCT fatura_no, musteri_kodu FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid),
acik AS (SELECT inv.* FROM inv LEFT JOIN paid p ON p.fatura_no=inv.fatura_no AND p.musteri_kodu=inv.musteri_kodu WHERE p.fatura_no IS NULL)
SELECT
  round(sum(tutar) FILTER (WHERE ok ~* 'vade|çek|mukabili|mahsuben')/1e6,1)      AS acik_kredili_m,
  round(sum(tutar) FILTER (WHERE ok !~* 'vade|çek|mukabili|mahsuben')/1e6,1)     AS acik_nakit_m,
  round(sum(tutar) FILTER (WHERE tutar<0)/1e6,1)                                  AS negatif_iade_m,
  round(sum(tutar) FILTER (WHERE ft > CURRENT_DATE-15)/1e6,1)                     AS son_15gun_m
  FROM acik;"
echo "  ⚠ acik_nakit_m buyukse: nakit fatura tahsilatta yok, yanlis 'acik' sayiliyor -> cikar."

hr "2. RAFINE ACIK = kredili faturalar, tahsilatta olmayan (nakit haric)"
$PSQL -c "
WITH inv AS (
  SELECT fatura_no, musteri_kodu, max(odeme_kosulu) ok, sum(satir_tutar) tutar
    FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2),
paid AS (SELECT DISTINCT fatura_no, musteri_kodu FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid)
SELECT round(sum(inv.tutar) FILTER (WHERE p.fatura_no IS NULL AND inv.ok ~* 'vade|çek|mukabili|mahsuben')/1e6,1) AS rafine_acik_m
  FROM inv LEFT JOIN paid p ON p.fatura_no=inv.fatura_no AND p.musteri_kodu=inv.musteri_kodu;"
echo "  HEDEF: 209.3M"

hr "3. ⚠ KDV kontrolu — satir_tutar net mi? (fatura_tutari ile ayni faturayi kiyasla)"
$PSQL -c "
WITH ortak AS (
  SELECT s.fatura_no, s.musteri_kodu, sum(s.satir_tutar) AS satis_net, max(t.fatura_tutari) AS tahsilat_tutar
    FROM bi_satis_faturalari s
    JOIN bi_fatura_tahsilat t ON t.fatura_no=s.fatura_no AND t.musteri_kodu=s.musteri_kodu AND t.tenant_id='$T'::uuid
   WHERE s.tenant_id='$T'
   GROUP BY 1,2 LIMIT 100000)
SELECT round(avg(tahsilat_tutar/nullif(satis_net,0)),3) AS ort_oran_brut_net
  FROM ortak WHERE satis_net>0;"
echo "  ⚠ ~1.20 ise: fatura_tutari KDV-dahil, satir_tutar KDV-haric. Mutabakatta bunu esitle."

hr "BITTI — rafine 209'a yaklastiysa Test A GECERLI"
