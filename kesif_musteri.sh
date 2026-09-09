#!/usr/bin/env bash
# MÜŞTERİ domain keşfi — ciro trendi + ödeme davranışı + vadesi geçmiş + limit + saha sinyali. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_musteri_risk — kolonlar + örnek (ödeme/limit/risk)"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_musteri_risk';" 2>&1 | sed 's/^/  /'
$PSQL -x -c "SELECT * FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND COALESCE(musteri_mi,true) ORDER BY vadesi_gecmis DESC NULLS LAST LIMIT 2;" 2>&1 | head -40 | sed 's/^/  /'

hr "2. bi_musteri_risk_odeme — ödeme davranışı kolonları"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_musteri_risk_odeme';" 2>&1 | sed 's/^/  /'

hr "3. bi_satis_faturalari — müşteri kimliği + tarih (ciro trendi için)"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_satis_faturalari' AND (column_name ~* 'musteri|cari|unvan|firma|hesap' OR column_name ~* 'tarih|tutar|satir');" 2>&1 | sed 's/^/  /'

hr "4. Müşteri ciro trendi denenebilir mi (son 6ay vs önceki 6ay, ilk 5)"
$PSQL -c "
WITH b AS (SELECT cari_kodu, max(cari_unvan) unvan,
  sum(satir_tutar) FILTER (WHERE fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE)) s,
  sum(satir_tutar) FILTER (WHERE fatura_tarihi>=date_trunc('month',CURRENT_DATE)-interval '12 month' AND fatura_tarihi<date_trunc('month',CURRENT_DATE)-interval '6 month') o
  FROM bi_satis_faturalari WHERE tenant_id::text='$T' GROUP BY cari_kodu)
SELECT unvan, round(o/1e6,1) onceki_M, round(s/1e6,1) simdi_M, round(100*(s-o)/nullif(o,0)) degisim_pct
FROM b WHERE o>2000000 AND s<o*0.6 ORDER BY (o-s) DESC LIMIT 5;" 2>&1 | sed 's/^/  /'

hr "5. saha_sinyal — müşteri bağlantısı (musteri_id) + örnek"
$PSQL -c "SELECT count(*) FILTER (WHERE musteri_id IS NOT NULL) musteri_bagli, count(*) toplam FROM saha_sinyal WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "BITTI — müşteri facts üreticisini bu şemaya göre yazarım."
