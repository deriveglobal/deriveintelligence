#!/usr/bin/env bash
# DENETIM_115J — KDV degisim tarihini VERIDEN oku (hafizadan degil). SADECE OKUR.
#   Ayni faturanin brut/net orani = 1+KDV. Aya gore 1.18 -> 1.20 hangi ay sicradi?
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. AY AY brut/net orani — KDV sicramasi ne zaman?"
$PSQL -c "
WITH ortak AS (
  SELECT date_trunc('month', s.fatura_tarihi)::date AS ay,
         sum(s.satir_tutar) AS net, max(t.fatura_tutari) AS brut
    FROM bi_satis_faturalari s
    JOIN bi_fatura_tahsilat t
      ON t.fatura_no=s.fatura_no AND t.musteri_kodu=s.musteri_kodu AND t.tenant_id='$T'::uuid
   WHERE s.tenant_id='$T'
   GROUP BY s.fatura_no, s.musteri_kodu, date_trunc('month', s.fatura_tarihi))
SELECT ay,
       round(sum(brut)/nullif(sum(net),0),4) AS brut_net_orani,
       count(*) AS fatura
  FROM ortak WHERE net>0
 GROUP BY ay ORDER BY ay;"
echo "  ⚠ Oran 1.18'den 1.20'ye ATLAYAN ay = KRB'nin fiili KDV degisim tarihi (veriden)."
echo "  ⚠ Not: dusuk KDV'li kalemler (bazi urunler) ortalamayi cekebilir — trend yine gorunur."

hr "BITTI — bu tarih, gecmis reconstruction'da dogru KDV oranini verir"
