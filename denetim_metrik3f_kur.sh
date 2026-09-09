#!/usr/bin/env bash
# METRIK 3F — 2 kati KUR mu, VERGI mi? ithal faturalar para birimi + kur. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_tedarikci_faturalari — para birimi / kur kolonu VAR MI?"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_tedarikci_faturalari'
            AND (column_name ~* 'para|doviz|kur|currency|birim_fiyat|tutar|tl') ORDER BY ordinal_position;"

hr "2. ATREZZO (3220004884-25) SAILUN faturasi — hangi para birimi, kur?"
$PSQL -c "SELECT * FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND kalem_kodu='3220004884-25' ORDER BY fatura_tarihi DESC LIMIT 3;" 2>&1 | sed 's/^/  /'

hr "3. TUM ithal faturalar para birimi dagilimi"
$PSQL -c "SELECT para_birimi, count(*), round(sum(birim_fiyat_kdv_haric*miktar)/1e6,1) tutar_m
          FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'
echo "  ⚠ USD/EUR varsa: ithal doviz. birim_fiyat TL mi orijinal doviz mi — 2. adim gosterir."

hr "4. ⚠ 699 TL mi USD mi? — SAILUN birim_fiyat mantikli mi (175/65R14 icin)"
echo "  ⚠ 699 TL ise: ucuz ama olası (Cin lastigi toptan). 699 USD ise: ~32.000 TL, sacma."
echo "     Para birimi 2. adimda TL ise -> fatura zaten TL'ye cevrilmis (tarihsel kur)."
echo "     -> O zaman kupun 1451'i: ya VERGI (landed) ya guncel-kur yeniden degerleme ya KIRLI."

hr "5. ⚠ bi_maliyet_ay 1451 nereden? — kup insasini kod/erp_ingest'te ara"
grep -nE "bi_maliyet_ay|maliyet_ay|birim_maliyet|landed|gumruk|kur|doviz" /opt/krb-assessment/erp_ingest.py 2>/dev/null | head -20 | sed 's/^/  /'

hr "BITTI — para birimi TL ise sorun kur DEGIL; kupun 1451 kaynagi kod'da aranmali"
