#!/usr/bin/env bash
# STOK GEÇMİŞ TESTİ — aylık reconstructed değer bugünü ~235M tutturuyor mu + trend mantıklı mı? SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. BUGÜN KONTROL — tüm-kalem reconstruction değeri (Σgiris−cikis>0 × ağırlıklı ort) ~235M mi?"
$PSQL -c "
WITH cost AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c
               FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY 1),
     qty  AS (SELECT kalem_kodu, sum(giris)-sum(cikis) q
               FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1)
SELECT round(sum(q.q*c.c) FILTER (WHERE q.q>0)/1e6,1) tum_kalem_recon_m,
       round(sum(q.q) FILTER (WHERE q.q>0)) pozitif_adet
  FROM qty q JOIN cost c USING(kalem_kodu);"
echo "  ⚠ ~235M'ye yakınsa geçmiş reconstruction VALUE olarak da güvenli (fazlalık adetler düşük değerli)."
echo "     Çok yüksekse (ör. 300M+) hayalet kalemler değeri şişiriyor → snapshot-only."

hr "2. AYLIK GEÇMİŞ DEĞER — son 15 ay-sonu, tüm-kalem reconstruction (trend mantıklı mı?)"
$PSQL -c "
WITH cost AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c
               FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY 1),
aylar AS (SELECT generate_series(date_trunc('month',CURRENT_DATE)-interval '14 month',
                                 date_trunc('month',CURRENT_DATE), interval '1 month')::date ay)
SELECT to_char(a.ay,'YYYY-MM') ay_sonu_oncesi,
       round(sum(GREATEST(qq.q,0)*c.c)/1e6,1) stok_deger_m
  FROM aylar a
  CROSS JOIN LATERAL (
     SELECT kalem_kodu, sum(giris)-sum(cikis) q
       FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND belge_tarihi < a.ay GROUP BY kalem_kodu
  ) qq
  JOIN cost c USING(kalem_kodu)
 GROUP BY a.ay ORDER BY a.ay;"
echo "  ⚠ Değerler 150-300M bandında yumuşak seyrediyorsa reconstruction kullanılabilir (yaklasik)."
echo "     Vahşi zıplama/negatif/absürt varsa güvenilmez → snapshot-only."

hr "BITTI — bu, stok geçmişinin kurulabilir olup olmadığını KESİN söyler."
