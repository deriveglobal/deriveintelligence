#!/usr/bin/env bash
# METRIK 3D — hangi maliyet guvenilir? Bir kalemin TUM alis + maliyet_ay gecmisi. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

# ATREZZO 175/65R14 kalem_kodu'nu bul
KK=$($PSQL -tAc "SELECT kalem_kodu FROM bi_stok_anlik WHERE tenant_id='$T'::uuid AND kalem_tanimi ILIKE '%175/65R14%ATREZZO%' LIMIT 1" | head -1 | tr -d '[:space:]')
echo "  Incelenen kalem_kodu: $KK  (ATREZZO 175/65R14)"

hr "1. ⚠ TUM ALIS GECMISI (bi_tedarikci_faturalari) — fiyat yorungesi"
$PSQL -c "
SELECT fatura_tarihi, round(birim_fiyat_kdv_haric) birim_fiyat, miktar, left(tedarikci_adi,24) tedarikci
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND kalem_kodu='$KK'
 ORDER BY fatura_tarihi DESC LIMIT 20;"
echo "  ⚠ Son fatura (700) yorungeye uyuyor mu, yoksa yalniz bir anomali mi?"

hr "2. ⚠ maliyet_ay GECMISI — kup ne diyor ay ay?"
$PSQL -c "
SELECT ay, round(birim_maliyet) maliyet_ay, adet
  FROM bi_maliyet_ay WHERE tenant_id='$T'::uuid AND kalem_kodu='$KK' ORDER BY ay DESC LIMIT 12;"

hr "3. ⚠ AGIRLIKLI ORTALAMA (gercek) — alislardan HESAPLA, kupe guvenme"
$PSQL -c "
SELECT round(sum(birim_fiyat_kdv_haric*miktar)/nullif(sum(miktar),0)) AS gercek_agirlikli_ort,
       round(min(birim_fiyat_kdv_haric)) min_fiyat, round(max(birim_fiyat_kdv_haric)) max_fiyat,
       count(*) fatura, sum(miktar) toplam_alinan
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND kalem_kodu='$KK' AND birim_fiyat_kdv_haric>0;"
echo "  ⚠ Gercek agirlikli ort ile kupun maliyet_ay'i (1451) UYUYOR mu?"
echo "     Uymuyorsa: kup KIRLI. Uyuyorsa: son alis (700) anomali, kup dogru."

hr "4. ⚠ SON 1 YIL alis — enflasyonda fiyat yukselmis mi dusmus mu?"
$PSQL -c "
SELECT date_trunc('quarter',fatura_tarihi)::date ceyrek,
       round(sum(birim_fiyat_kdv_haric*miktar)/nullif(sum(miktar),0)) ort_fiyat, sum(miktar) adet
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND kalem_kodu='$KK' AND birim_fiyat_kdv_haric>0
   AND fatura_tarihi>=CURRENT_DATE-540
 GROUP BY 1 ORDER BY 1 DESC;"

hr "BITTI — bu, hangi maliyetin gercek oldugunu soyleyecek"
