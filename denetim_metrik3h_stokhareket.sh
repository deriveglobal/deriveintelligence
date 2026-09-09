#!/usr/bin/env bash
# METRIK 3H — ERP Sailun'u STOGA KACA ALDI? giris vs cikis maliyeti. Kesin test. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_stok_hareket — TUM kolonlar (giris/cikis/tutar/tip)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_stok_hareket' ORDER BY ordinal_position;"

hr "2. ⚠ SAILUN (3220004884-25) — GIRIS vs CIKIS birim maliyeti"
$PSQL -c "
SELECT
  round(sum(giris)) toplam_giris, round(sum(cikis)) toplam_cikis,
  round(sum(giris_tutari)/nullif(sum(giris),0))  AS giris_birim,
  round(sum(cikis_tutari)/nullif(sum(cikis),0))  AS cikis_birim,
  round(avg(birim_maliyet)) ort_birim_maliyet
  FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='3220004884-25';" 2>&1 | sed 's/^/  /'
echo "  ⚠ giris_birim 699 ise: ERP 699'a almis -> cikis 1451 SISIK -> kup KIRLI -> son alis (274M) DOGRU."
echo "  ⚠ giris_birim 1451 ise: ERP gercekten yuksek almis (sebep aranir)."

hr "3. ⚠ SAILUN GIRIS hareketleri — belge belge (nereden 1451?)"
$PSQL -c "
SELECT belge_tarihi, round(giris) giris, round(giris_tutari) giris_tutari,
       round(giris_tutari/nullif(giris,0)) birim, round(birim_maliyet) birim_maliyet
  FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='3220004884-25' AND giris>0
 ORDER BY belge_tarihi DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "4. ⚠ GENEL — kupun cikis_birim'i, alis faturasindan sistematik yuksek mi? (10 kalem)"
$PSQL -c "
WITH sa AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric f FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0 ORDER BY kalem_kodu, fatura_tarihi DESC),
gh AS (SELECT kalem_kodu, sum(giris_tutari)/nullif(sum(giris),0) giris_birim, sum(cikis_tutari)/nullif(sum(cikis),0) cikis_birim
         FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1)
SELECT left(s.kalem_tanimi,30) urun, round(sa.f) alis_faturasi, round(gh.giris_birim) giris_maliyet, round(gh.cikis_birim) cikis_maliyet
  FROM bi_stok_anlik s JOIN sa ON sa.kalem_kodu=s.kalem_kodu JOIN gh ON gh.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid AND s.marka='SAILUN' AND s.adet>0 ORDER BY s.adet DESC LIMIT 10;"
echo "  ⚠ giris_maliyet ≈ alis_faturasi ise: giris dogru, cikis sisik (kup kirli)."

hr "BITTI — bu, son alis mi kup mu guvenilir KESIN soyler"
