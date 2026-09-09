#!/usr/bin/env bash
# DENETIM_115E — DUZELTILMIS: pesin/vadeli odeme_kosulu'ndan; join anahtari once bulunur. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. bi_musteri_risk — musteri anahtari HANGI kolon? (join icin)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_musteri_risk' AND
          (column_name ILIKE '%kod%' OR column_name ILIKE '%cari%' OR column_name ILIKE '%musteri%' OR column_name ILIKE '%unvan%' OR column_name ILIKE '%ad%')
          ORDER BY ordinal_position;"

hr "1. ⚠ DOGRU SINYAL — odeme_kosulu ile pesin/vadeli (vade_tarihi DEGIL)"
echo "  KREDI = 'Vade'/'Çek'/'Mukabili'/'mahsuben' iceren; PESIN = Peşin/Sanal POS/Havale"
$PSQL -c "
SELECT CASE WHEN ebat IS NOT NULL THEN 'LASTIK' ELSE 'lastik-disi' END AS grup,
       round(sum(satir_tutar)/1e6,1) AS toplam_m,
       round(sum(satir_tutar) FILTER (WHERE odeme_kosulu ~* 'vade|çek|mukabili|mahsuben')/1e6,1) AS kredi_m,
       round(100.0*sum(satir_tutar) FILTER (WHERE odeme_kosulu ~* 'vade|çek|mukabili|mahsuben')/nullif(sum(satir_tutar),0)) AS kredi_pct
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365
 GROUP BY 1;"
echo "  ⚠ lastik-disi kredi_pct DUSUKSE -> alacak yaratmiyor -> alacak fiilen lastik (B)."
echo "     YUKSEKSE -> lastik-disi de vadeli -> bolunemez, sirket geneli DSO (A)."

hr "2. ⚠ KREDILI ciro toplami — DSO paydasi icin dogru evren bu olabilir"
$PSQL -c "
SELECT round(sum(satir_tutar) FILTER (WHERE odeme_kosulu ~* 'vade|çek|mukabili|mahsuben')/1e6,1) AS kredili_ciro_m,
       round(sum(satir_tutar)/1e6,1) AS tum_ciro_m,
       round(sum(satir_tutar) FILTER (WHERE odeme_kosulu ~* 'vade|çek|mukabili|mahsuben' AND ebat IS NOT NULL)/1e6,1) AS kredili_lastik_m
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365;"
echo "  ⚠ Purist DSO = alacak ÷ gunluk KREDILI satis (pesin alacak yaratmaz)."

hr "BITTI — join anahtari bulununca saf-servis bakiye kontrolu de yapilir (bir sonraki)"
