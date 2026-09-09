#!/usr/bin/env bash
# DENETIM_115D — lastik-disi satis ALACAK yaratiyor mu? Varsayimsiz, VERIDEN. OKUR.
#   B secenegi: cevap "hayir, pesin" ise alacak fiilen lastik (olcum). "evet, vadeli" ise sirket geneli (A).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. odeme_kosulu — hangi degerler var? (pesin/vadeli ayrimi mumkun mu?)"
$PSQL -c "SELECT odeme_kosulu, count(*) FROM bi_satis_faturalari
          WHERE tenant_id='$T' GROUP BY 1 ORDER BY 2 DESC LIMIT 25;"

hr "2. vade_tarihi — dolu mu? (vadeli satis isareti)"
$PSQL -c "SELECT count(*) FILTER (WHERE vade_tarihi IS NOT NULL) AS vadeli,
                 count(*) FILTER (WHERE vade_tarihi IS NULL)     AS vadesiz_pesin,
                 count(*) AS toplam
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND fatura_tarihi>=CURRENT_DATE-365;"

hr "3. ⚠ LASTIK vs LASTIK-DISI: her biri ne kadar VADELI?"
$PSQL -c "
SELECT CASE WHEN ebat IS NOT NULL THEN 'LASTIK' ELSE 'lastik-disi' END AS grup,
       round(sum(satir_tutar)/1e6,1) AS ciro_m,
       round(100.0*count(*) FILTER (WHERE vade_tarihi IS NOT NULL)/nullif(count(*),0)) AS vadeli_pct
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365
 GROUP BY 1;"
echo "  ⚠ lastik-disi vadeli_pct DUSUKSE -> alacak yaratmiyor -> alacak fiilen lastik (B gecerli)."
echo "     YUKSEKSE -> lastik-disi de alacak yaratiyor -> bolunemez, sirket geneli DSO (A)."

hr "4. ⚠ SADECE lastik-disi alan musteriler ALACAK tasiyor mu? (dogrudan kanit)"
$PSQL -c "
WITH mix AS (
  SELECT musteri_kodu,
         sum(satir_tutar) FILTER (WHERE ebat IS NOT NULL) AS lastik,
         sum(satir_tutar) AS tot
    FROM bi_satis_faturalari
   WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365
   GROUP BY 1),
sadece_servis AS (SELECT musteri_kodu FROM mix WHERE COALESCE(lastik,0)=0 AND tot>0)
SELECT count(DISTINCT ss.musteri_kodu) AS sadece_servis_musteri,
       count(DISTINCT r.musteri_kodu) FILTER (WHERE r.hesap_bakiyesi>0) AS bakiyesi_olan,
       round(sum(r.hesap_bakiyesi)/1e6,2) AS toplam_bakiye_m
  FROM sadece_servis ss
  LEFT JOIN bi_musteri_risk r ON r.musteri_kodu=ss.musteri_kodu AND r.tenant_id='$T'::uuid AND r.musteri_mi;"
echo "  ⚠ 'sadece servis' musterilerin toplam bakiyesi ~0 ise: lastik-disi alacak yaratmiyor (B kanit)."
echo "     Buyukse: lastik-disi de alacak yaratiyor (A)."

hr "BITTI — cevap A/B secimini VERIDEN veriyor, varsayimdan degil"
