#!/usr/bin/env bash
# DENETIM_115F — A vs B SIMULASYONU. Veri konussun. SADECE OKUR.
#   A = sirket geneli (varsayimsiz). B = alacagi lastige dagit (varsayim) + kirilganlik araligi.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. ⚠ JOIN KAPSAMI — alacak musterileri satis musterileriyle eslesiyor mu?"
$PSQL -c "
WITH ar AS (SELECT muhatap_kodu, hesap_bakiyesi FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi AND hesap_bakiyesi>0),
mix AS (SELECT DISTINCT musteri_kodu FROM bi_satis_faturalari WHERE tenant_id='$T' AND fatura_tarihi>=CURRENT_DATE-365)
SELECT count(*) AS alacakli_musteri,
       count(*) FILTER (WHERE m.musteri_kodu IS NOT NULL) AS satisla_eslesen,
       round(sum(ar.hesap_bakiyesi)/1e6,1) AS toplam_alacak_m,
       round(sum(ar.hesap_bakiyesi) FILTER (WHERE m.musteri_kodu IS NOT NULL)/1e6,1) AS eslesen_alacak_m
  FROM ar LEFT JOIN mix m ON m.musteri_kodu = ar.muhatap_kodu;"
echo "  ⚠ Eslesme dusukse (eski borc, satisi olmayan musteri): B zaten guvenilmez — dagitilamaz."

hr "1. A — SIRKET GENELI (varsayimsiz): alacak ÷ gunluk kredili satis"
$PSQL -c "
WITH ar AS (SELECT sum(hesap_bakiyesi) v FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi),
kredi AS (SELECT sum(satir_tutar)/365.0 g FROM bi_satis_faturalari
          WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365
            AND odeme_kosulu ~* 'vade|çek|mukabili|mahsuben')
SELECT round((SELECT v FROM ar)/1e6,1) alacak_m,
       round((SELECT g FROM kredi)/1e6,2) gunluk_kredili_m,
       round((SELECT v FROM ar)/(SELECT g FROM kredi)) AS DSO_A;"

hr "2. B — DAGITIM (varsayim) + KIRILGANLIK ARALIGI"
$PSQL -c "
WITH
mix AS (
  SELECT musteri_kodu,
    sum(satir_tutar) FILTER (WHERE ebat IS NOT NULL AND odeme_kosulu ~* 'vade|çek|mukabili|mahsuben') AS tire_kredi,
    sum(satir_tutar) FILTER (WHERE odeme_kosulu ~* 'vade|çek|mukabili|mahsuben')                       AS tum_kredi
  FROM bi_satis_faturalari WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365 GROUP BY 1),
ar AS (SELECT muhatap_kodu, hesap_bakiyesi FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi AND hesap_bakiyesi>0),
j AS (
  SELECT ar.hesap_bakiyesi AS bak,
         COALESCE(m.tire_kredi,0) AS tk, COALESCE(m.tum_kredi,0) AS mk,
         CASE WHEN COALESCE(m.tum_kredi,0)>0 THEN m.tire_kredi/m.tum_kredi ELSE NULL END AS lastik_pay
    FROM ar LEFT JOIN mix m ON m.musteri_kodu = ar.muhatap_kodu),
lastik_kredi AS (SELECT sum(satir_tutar)/365.0 g FROM bi_satis_faturalari
  WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365
    AND ebat IS NOT NULL AND odeme_kosulu ~* 'vade|çek|mukabili|mahsuben')
SELECT
  -- B-orantili: alacak × lastik payi (eslesmeyeni tam say — ust yanli)
  round(sum(bak * COALESCE(lastik_pay,1))/1e6,1)                                  AS tire_AR_orantili_m,
  round(sum(bak * COALESCE(lastik_pay,1)) / (SELECT g FROM lastik_kredi))         AS DSO_B_orantili,
  -- B-ust: lastik alan her musterinin TAM bakiyesi lastik
  round(sum(bak) FILTER (WHERE tk>0) / (SELECT g FROM lastik_kredi))              AS DSO_B_ust,
  -- B-alt: sadece SAF lastik musteri (lastik_pay=1)
  round(sum(bak) FILTER (WHERE lastik_pay>=0.999) / (SELECT g FROM lastik_kredi)) AS DSO_B_alt
  FROM j;"

hr "3. ⚠ KARAR — A tek sayi mi, B genis aralik mi?"
echo "  A: tek, varsayimsiz sayi."
echo "  B: orantili + [alt..ust] araligi. Bu aralik GENISSE, B varsayimi karar veremeyecek kadar oynak."
echo "  ⚠ Ayrica lastik_pay orantisi = alacak satis gibi bolunur VARSAYIMI — veride kanit YOK."

hr "BITTI — sayilar A/B'yi konussun"
