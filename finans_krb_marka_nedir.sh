#!/usr/bin/env bash
# marka='KRB' NE — hangi ürünler, kategori, trend. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. marka='KRB' — örnek kalemler (bu satırlar NE satıyor)"
$PSQL -c "SELECT left(kalem_tanimi,50) kalem, kategori, grup_adi, count(*) adet_satir
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND marka='KRB' AND ebat IS NOT NULL
          GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 15;"

hr "2. KATEGORİ / GRUP dağılımı (KRB markası hangi tip)"
$PSQL -c "SELECT kategori, grup_adi, count(*), round(sum(satir_tutar)/1e6,1) ciro_m
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND marka='KRB' AND ebat IS NOT NULL
          GROUP BY 1,2 ORDER BY 4 DESC LIMIT 10;"

hr "3. YILLIK TREND — KRB markası ne zaman düştü"
$PSQL -c "SELECT to_char(date_trunc('year',fatura_tarihi),'YYYY') yil,
                 round(sum(satir_tutar)/1e6,1) ciro_m, count(*) satir
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND marka='KRB' AND ebat IS NOT NULL
          GROUP BY 1 ORDER BY 1;"

hr "4. KAPLAMA MI — kalem_tanimi'nde kaplama/retread/yenileme geçiyor mu"
$PSQL -c "SELECT count(*) FILTER (WHERE kalem_tanimi ~* 'kaplama|retread|yenile|sirt') AS kaplama_ihtimali,
                 count(*) toplam
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND marka='KRB' AND ebat IS NOT NULL;"

hr "BITTI — KRB markasının ne olduğu görülecek (kaplama/özel/markasız?)."
