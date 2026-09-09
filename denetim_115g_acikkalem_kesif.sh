#!/usr/bin/env bash
# DENETIM_115G — Test A KESIF: faturalar + tahsilatlar acik kalemi kurabilir mi? SADECE OKUR.
#   Uydurma kolon yok — once yapiyi gor, sonra mutabakat.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_satis_faturalari — KOLONLAR (fatura no / tutar / tarih / vade / tahsil?)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_satis_faturalari' ORDER BY ordinal_position;"

hr "2. bi_fatura_tahsilat — TUM KOLONLAR (bu tablo neyi temsil ediyor?)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_fatura_tahsilat' ORDER BY ordinal_position;"

hr "3. TARIH ARALIKLARI — 6 yil geriye gidiyor mu? (acilis bakiyesi sorunu)"
$PSQL -c "SELECT 'satis' t, min(fatura_tarihi) ilk, max(fatura_tarihi) son, count(*) satir
          FROM bi_satis_faturalari WHERE tenant_id='$T'
          UNION ALL
          SELECT 'tahsilat', min(fatura_tarihi), max(fatura_tarihi), count(*)
          FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "4. ORTAK ANAHTAR — fatura_no / belge_no iki tabloda da var mi?"
echo "  --- satis faturalari 'no' iceren kolonlar ---"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_satis_faturalari' AND (column_name ILIKE '%no%' OR column_name ILIKE '%belge%' OR column_name ILIKE '%fatura%');" 2>&1 | sed 's/^/  /'
echo "  --- tahsilat 'no' iceren kolonlar ---"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_fatura_tahsilat' AND (column_name ILIKE '%no%' OR column_name ILIKE '%belge%' OR column_name ILIKE '%fatura%');" 2>&1 | sed 's/^/  /'

hr "5. KABA MUTABAKAT — toplam kredili fatura − toplam tahsilat ≈ 209M mi?"
echo "  --- tum zamanlar kredili fatura toplami ---"
$PSQL -c "SELECT round(sum(satir_tutar)/1e6,1) AS kredili_fatura_toplam_m
          FROM bi_satis_faturalari WHERE tenant_id='$T'
            AND odeme_kosulu ~* 'vade|çek|mukabili|mahsuben';" 2>&1 | sed 's/^/  /'
echo "  --- bi_fatura_tahsilat toplami (bu tablo tahsil edileni mi tutuyor?) ---"
$PSQL -c "SELECT round(sum(fatura_tutari)/1e6,1) AS tahsilat_tablo_toplam_m, count(*) satir
          FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  --- HEDEF: bugunku acik alacak ---"
$PSQL -c "SELECT round(sum(hesap_bakiyesi)/1e6,1) AS acik_alacak_m
          FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi;" 2>&1 | sed 's/^/  /'

hr "6. bi_fatura_tahsilat — ORNEK 3 satir (ne demek istedigi anlasilsin)"
$PSQL -c "SELECT * FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid LIMIT 3;" 2>&1 | sed 's/^/  /'

hr "BITTI — yapi netlesince acik-kalem mutabakatini dogru kurarim"
