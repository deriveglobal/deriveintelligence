#!/usr/bin/env bash
# ALACAK KESİN 2 — tanımı çöz: çek/senet + geleceğe giden tarih + hangi tanım 209M'yi tutturuyor. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TAHSİLAT TÜRÜ dağılımı + odeme_tarihi geleceğe giden satırlar hangi tür?"
$PSQL -c "SELECT tahsilat_turu, count(*),
                 count(*) FILTER (WHERE odeme_tarihi > CURRENT_DATE) gelecek_tarihli,
                 round(sum(odenen_tutar) FILTER (WHERE odeme_tarihi > CURRENT_DATE)/1e6,1) gelecek_tutar_m
          FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Gelecek tarihliler ağırlıkla Çek/Senet ise: bunlar ileri vadeli, henüz tahsil edilmemiş."

hr "2. ÖRNEK — geleceğe giden tahsilatlar (fatura vs odeme vs vade tarihi, gerçek satır)"
$PSQL -c "SELECT fatura_tarihi::text, odeme_tarihi::text, tahsilat_vade_tarihi::text, tahsilat_turu, round(odenen_tutar) odenen
          FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid AND odeme_tarihi > CURRENT_DATE
          ORDER BY odeme_tarihi DESC LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "3. ⚠ ÜÇ TANIM — bugünkü açık alacak, her biri 209M ile kıyas"
$PSQL -c "
WITH inv AS (SELECT fatura_no, max(fatura_tutari) tutar, min(fatura_tarihi) ftar FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid GROUP BY fatura_no),
p_ode AS (SELECT fatura_no, sum(odenen_tutar) p FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid AND odeme_tarihi<=CURRENT_DATE GROUP BY fatura_no),
p_hep AS (SELECT fatura_no, sum(odenen_tutar) p FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid GROUP BY fatura_no)
SELECT
  round(sum(GREATEST(i.tutar-COALESCE(a.p,0),0))/1e6,1) AS a_cek_HARIC_bekleyen_acik_m,
  round(sum(GREATEST(i.tutar-COALESCE(b.p,0),0))/1e6,1) AS b_cek_DAHIL_tum_odeme_kapatir_m
  FROM inv i LEFT JOIN p_ode a USING(fatura_no) LEFT JOIN p_hep b USING(fatura_no) WHERE i.ftar<=CURRENT_DATE;"
$PSQL -c "SELECT round(sum(hesap_bakiyesi)/1e6,1) erp_209_m FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND COALESCE(musteri_mi,true);"
echo "  ⚠ a (odeme_tarihi<=bugün, çek beklemede açık) ~242 · b (tüm ödeme kapatır, çek dahil) ~? · ERP 209."
echo "     Hangisi 209'a yakınsa ERP tanımı odur; fark = çek/senet yüzeri."

hr "4. EKSİK FATURA EVRENİ — bi_satis_faturalari'nda olup tahsilat defterinde OLMAYAN (tam açık)"
$PSQL -c "
WITH odenmis AS (SELECT DISTINCT fatura_no FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid)
SELECT count(DISTINCT s.fatura_no) eksik_fatura,
       round(sum(s.satir_tutar)/1e6,1) eksik_net_tutar_m
  FROM bi_satis_faturalari s
 WHERE s.tenant_id='$T' AND s.fatura_no NOT IN (SELECT fatura_no FROM odenmis);"
echo "  ⚠ Bu faturalar hiç tahsil edilmemiş (tam açık) → kesin alacak evrenine EKLENMELİ."

hr "BITTI — çek/senet farkı + eksik evren ölçüldü. Tanım kararı verilince kesin fonksiyon kurulur."
