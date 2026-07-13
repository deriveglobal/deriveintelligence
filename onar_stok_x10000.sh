#!/usr/bin/env bash
# STOK_X10000_ONARIM — bi_stok_anlik.kullanilabilir ×10.000 bozulmasi.
#
# ⚠ KANIT: 2.185 SKU'nun 2.134'unde kullanilabilir/adet = TAM 10000.
#   Turkce ondalik virgul: "889,0000" -> 8890000. Ayni hata Haziran'da
#   SATIS tablosunda bulunmus ve onarilmisti. STOK tablosunda DURUYORMUS.
#   Ayni hata, farkli tablo, kimse bakmamis.
#
# ⚠ ONARIM GUVENLI CUNKU BOZULMA TUTARLI:
#   kullanilabilir / 10000 == adet - taahhut  (kendi icinde dogrulanabilir)
#   Bu esitlik tutmayan satir varsa DOKUNMUYORUZ.
#
# ⚠ AYRICA: taahhut neredeyse BOS (5,4M). ERP taahhutlu stogu TAKIP ETMIYOR.
#   "Hangi stoga dokunulmaz" sorusu bu tablodan CEVAPLANMAZ -> bi_on_siparis.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';

\echo '════ 1) ONCE: bozulma dagilimi ════'
SELECT CASE WHEN adet=0 THEN 'adet=0'
            WHEN abs(kullanilabilir/10000.0 - (adet-COALESCE(taahhut,0))) < 0.01 THEN '✅ ONARILABILIR (÷10000 == adet-taahhut)'
            WHEN abs(kullanilabilir - (adet-COALESCE(taahhut,0))) < 0.01        THEN '○ ZATEN DOGRU'
            ELSE '⚠ ACIKLANAMAYAN — DOKUNMA' END AS durum,
       count(*), round(sum(adet)) AS adet
  FROM bi_stok_anlik WHERE tenant_id='$TEN'::uuid
 GROUP BY 1 ORDER BY 2 DESC;

\echo ''
\echo '════ 2) ONARIM — SADECE esitligi dogrulananlar ════'
UPDATE bi_stok_anlik
   SET kullanilabilir = kullanilabilir / 10000.0
 WHERE tenant_id='$TEN'::uuid
   AND adet > 0
   AND abs(kullanilabilir/10000.0 - (adet - COALESCE(taahhut,0))) < 0.01;

\echo ''
\echo '════ 3) ⚠ KAPI: onarim sonrasi kullanilabilir <= adet OLMALI ════'
SELECT count(*) AS ihlal FROM bi_stok_anlik
 WHERE tenant_id='$TEN'::uuid AND adet>0 AND kullanilabilir > adet * 1.01 \gset
SELECT CASE WHEN :ihlal > 0 THEN (SELECT 1/0) ELSE 1 END AS kapi_ok;

\echo ''
\echo '════ 4) SONRA: gercek rakamlar ════'
WITH sa AS (
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku,
         birim_fiyat_kdv_haric fiyat
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC)
SELECT round(sum(st.adet*sa.fiyat)/1e6,1)           AS stok_M,
       round(sum(st.taahhut*sa.fiyat)/1e6,1)        AS taahhutlu_M,
       round(sum(st.kullanilabilir*sa.fiyat)/1e6,1) AS SERBEST_M
  FROM bi_stok_anlik st
  LEFT JOIN sa ON sa.sku=bi_sku_norm(st.kalem_kodu)
 WHERE st.tenant_id='$TEN'::uuid AND st.adet>0;
\echo '  ^ SERBEST artik 2,4 TRILYON degil.'

COMMIT;
SQL
[ $? -ne 0 ] && { echo "❌ KAPI PATLADI — onarim GERI ALINDI"; exit 1; }

echo
echo "════ 5) ⚠⚠ ASIL SORU: taahhut BOS. Dokunulmaz stok NEREDE? ════"
$PSQL -c "
SET app.current_tenant_id='$TEN';
\echo '  ERP taahhutlu stogu takip etmiyor (5,4M). Gercek taahhut ON SIPARISTE:'
SELECT count(*) AS satir, sum(siparis_adet) AS siparis_adet,
       sum(COALESCE(gelen_adet,0)) AS gelen, sum(COALESCE(bekleyen_adet,0)) AS bekleyen
  FROM bi_on_siparis WHERE tenant_id='$TEN';" 2>&1 | head -12

echo
echo "  ⚠ 'Stogu 105M azalt' tavsiyesi ON SIPARISE bagli stoga DOKUNAMAZ."
echo "     Taahhut kaynagi: bi_on_siparis. bi_stok_anlik.taahhut GUVENILMEZ."

cd /opt/krb-assessment 2>/dev/null && git add -A 2>/dev/null && git commit -q -m "fix(veri): STOK_X10000 — bi_stok_anlik.kullanilabilir Turkce ondalik virgul bozulmasi (×10.000). 2.185 SKU'nun 2.134'unde kullanilabilir/adet = TAM 10000. Serbest stok degeri 2,4 TRILYON TL gorunuyordu (gercek toplam stok 268,5M). Ayni hata Haziran'da SATIS tablosunda bulunup onarilmisti — STOK tablosunda duruyormus, kimse bakmamis. Onarim guvenli: bozulma tutarli, kullanilabilir/10000 == adet-taahhut esitligi her satirda dogrulandi; tutmayan satira DOKUNULMADI. ⚠ AYRICA taahhut neredeyse bos (5,4M) — ERP taahhutlu stogu takip etmiyor; 'dokunulmaz stok' bi_on_siparis'ten gelmeli." 2>/dev/null && echo "  COMMITTED"
