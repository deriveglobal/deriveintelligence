#!/usr/bin/env bash
# METRIK 3G — ITHALAT GIDERI VAR MI? teori kanit ister. Bulunamazsa GERI CEK. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_tedarikci_faturalari — SADECE lastik mi, gider/gumruk satiri var mi?"
$PSQL -c "SELECT grup_adi, count(*), round(sum(satir_kdv_haric)/1e6,1) tutar_m
          FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 3 DESC NULLS LAST LIMIT 25;"

hr "2. ANAHTAR KELIME — gumruk/ithalat/navlun/damping/vergi/nakliye/lojistik hangi kalemde?"
$PSQL -c "
SELECT left(kalem_tanimi,45) kalem, count(*), round(sum(satir_kdv_haric)/1e6,2) tutar_m
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid
   AND (kalem_tanimi ~* 'gumruk|gümrük|ithalat|navlun|damping|nakliye|lojistik|freight|customs|vergi|antidamping|anti-damping')
 GROUP BY 1 ORDER BY 3 DESC NULLS LAST LIMIT 20;"
echo "  ⚠ Bos ise: bu tabloda ithalat gideri YOK."

hr "3. LOJISTIK/BROKER tedarikciler — KRB onlara ne kadar odemis?"
$PSQL -c "
SELECT left(tedarikci_adi,42) tedarikci, count(*) fatura, round(sum(satir_kdv_haric)/1e6,2) tutar_m
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid
   AND tedarikci_adi ~* 'loj|nakliy|gumruk|gümrük|dis ticaret|dış ticaret|freight|customs|group'
 GROUP BY 1 ORDER BY 3 DESC NULLS LAST LIMIT 15;"
echo "  ⚠ Bu tutarlar ithalat masrafi olabilir — ama lastik ALIS mi masraf mi ayirt et."

hr "4. ⚠ ASIL TEST — SAILUN kaleminin GIRIS (stok_hareket) maliyeti = 1451 mi 699 mu?"
$PSQL -c "
SELECT hareket_tipi, count(*), round(avg(birim_maliyet)) ort_birim_maliyet, sum(giris) giris, sum(cikis) cikis
  FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='3220004884-25'
 GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'
echo "  ⚠ GIRIS birim_maliyet 1451 ise: ERP mali 1451'e STOGA ALMIS -> 752 fark bir yerden geldi (gumruk?)."
echo "     GIRIS birim_maliyet 699 ise: ERP 699'a almis, 1451 SATIS maliyeti sisik -> kup KIRLI, teori YANLIS."

hr "5. TUM tablolarda gumruk/ithalat/gider kolonu/tablosu"
$PSQL -c "SELECT table_name, column_name FROM information_schema.columns
          WHERE (column_name ~* 'gumruk|ithalat|navlun|gider|masraf|damping|landed|freight|customs')
          ORDER BY 1;" 2>&1 | sed 's/^/  /'
echo "  --- gider/ithalat isimli tablo ---"
$PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ~* 'gider|masraf|ithalat|gumruk|expense');" 2>&1 | sed 's/^/  /'

hr "BITTI — gider bulunursa teori kanit; bulunmazsa 'landed cost' iddiasi GERI CEKILIR"
