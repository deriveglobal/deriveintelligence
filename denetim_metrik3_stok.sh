#!/usr/bin/env bash
# METRIK 3 — STOK DEGERI. Sablon: fonksiyon + capraz-kontrol + SINIR. SADECE OKUR.
#   ⚠ Stok URUNE BOLUNEBILIR (ebat var) -> lastik-only TEMIZ. Ama maliyet stokta YOK, alistan baglanir.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_stok_anlik — YAPI (adet / kalem_kodu / ebat / maliyet var mi?)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_stok_anlik' ORDER BY ordinal_position;"

hr "2. MALIYET KAYNAKLARI — capraz-kontrol icin (bi_maliyet_sku / bi_maliyet_ay)"
echo "  --- bi_maliyet_sku kolonlari ---"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='bi_maliyet_sku' ORDER BY ordinal_position;" 2>&1 | sed 's/^/  /'
echo "  --- bi_maliyet_ay kolonlari (ilk 12) ---"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_maliyet_ay' ORDER BY ordinal_position LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "3. FONKSIYON A — stok = SUM(adet × SON ALIS birim fiyati), kalem_kodu ile"
$PSQL -c "
WITH son_alis AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS fiyat
    FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT
  round(sum(s.adet * a.fiyat)/1e6,1)                                          AS stok_toplam_m,
  round(sum(s.adet * a.fiyat) FILTER (WHERE s.ebat IS NOT NULL)/1e6,1)        AS stok_lastik_m,
  round(sum(s.adet) FILTER (WHERE a.fiyat IS NULL))                           AS maliyetsiz_adet,
  count(*) FILTER (WHERE a.fiyat IS NULL)                                     AS maliyetsiz_kalem
  FROM bi_stok_anlik s
  LEFT JOIN son_alis a ON a.kalem_kodu = s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  ⚠ maliyetsiz_adet = alis faturasi eslesmeyen -> stok degeri BU KADAR EKSIK (kor nokta, gizleme)."

hr "4. ⚠ CAPRAZ-KONTROL B — bi_maliyet_sku ile ayni stok degeri cikiyor mu?"
$PSQL -c "
SELECT round(sum(s.adet * m.birim_maliyet)/1e6,1) AS stok_maliyet_sku_m, count(*) eslesen
  FROM bi_stok_anlik s
  JOIN bi_maliyet_sku m ON m.kalem_kodu = s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  ⚠ (kolon adi farkliysa hata verir — 2. adimdan gercek adi alip duzeltirim)"
echo "  ⚠ A ile B yakinsa (birkac %): stok degeri capraz-dogrulandi. Uzaksa maliyet yontemi onemli (SINIR)."

hr "5. ⚠ TIRE KAPSAM — stok gercekten ebat ile lastige suzuluyor mu?"
$PSQL -c "
SELECT count(*) FILTER (WHERE ebat IS NOT NULL) AS lastik_kalem,
       count(*) FILTER (WHERE ebat IS NULL)     AS ebatsiz_kalem,
       count(*) AS toplam
  FROM bi_stok_anlik WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  ⚠ Stok pozisyon ama URUNE BOLUNEBILIR — alacak/borctan farki bu. lastik-only temiz."

hr "BITTI"
