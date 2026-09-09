#!/usr/bin/env bash
# DENETIM_115B — DSO'yu BAGIMSIZ yontemle capraz-kontrol et. SADECE OKUR.
#   Oran yontemi: 81. Geri-sayim yontemi ile ortusuyor mu? + kredi/pesin ayrimi mumkun mu?
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ORAN YONTEMI (referans) — alacak ÷ gunluk tum ciro"
$PSQL -c "
WITH a AS (SELECT sum(hesap_bakiyesi) v FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi),
     c AS (SELECT sum(satir_tutar)/365.0 g FROM bi_satis_faturalari WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365)
SELECT round((SELECT v FROM a)/1e6,1) alacak_m, round((SELECT g FROM c)/1e6,2) gunluk_ciro_m,
       round((SELECT v FROM a)/(SELECT g FROM c)) AS dso_oran;"

hr "2. ⚠ BAGIMSIZ: GERI-SAYIM — gunluk satislari geriye topla, alacaga esitle"
$PSQL -c "
WITH ar AS (SELECT sum(hesap_bakiyesi) v FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi),
gunluk AS (
  SELECT fatura_tarihi::date d, sum(satir_tutar) c
    FROM bi_satis_faturalari
   WHERE tenant_id='$T' AND miktar>0 AND fatura_tarihi<=CURRENT_DATE AND fatura_tarihi>=CURRENT_DATE-400
   GROUP BY 1),
kum AS (SELECT d, sum(c) OVER (ORDER BY d DESC) AS running FROM gunluk)
SELECT (CURRENT_DATE - min(d)) AS geri_sayim_dso_gun
  FROM kum WHERE running <= (SELECT v FROM ar);"
echo "  ⚠ Oran (~81) ile geri-sayim ORTUSMELI. Buyuk fark = mevsimsellik ya da tanim sorunu."

hr "3. ⚠ SINIR: KREDI mi PESIN mi? — pesin satis DSO'yu dusurur, ayirabilir miyiz?"
$PSQL -c "SELECT column_name FROM information_schema.columns
          WHERE table_name='bi_satis_faturalari' AND
          (column_name ILIKE '%vade%' OR column_name ILIKE '%odeme%' OR column_name ILIKE '%pesin%' OR column_name ILIKE '%kredi%' OR column_name ILIKE '%tahsil%');"
echo "  ⚠ Vade/odeme tipi kolonu varsa: purist DSO = alacak ÷ gunluk KREDILI satis."
echo "     Yoksa: tum satis kullanilir, pesin varsa DSO bir miktar DUSUK cikar (SINIR notu)."

hr "4. ⚠ CAPRAZ: yaslandirma tutarlilik — %69 vadesi gecmis ile 81 uyumlu mu?"
$PSQL -c "
SELECT round(sum(hesap_bakiyesi)/1e6,1) alacak_m,
       round(sum(vadesi_gecmis)/1e6,1)  vadesi_gecmis_m,
       round(100.0*sum(vadesi_gecmis)/nullif(sum(hesap_bakiyesi),0)) gecikmis_pct
  FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi;"
echo "  ⚠ %69 vadesi gecmis + 30-90 gun vade -> ortalama yas VADENIN COK USTUNDE."
echo "     22 gun (odenen faturalar) portfoy DSO'su OLAMAZ; 81 yaslandirmayla tutarli."

hr "BITTI — geri-sayim 81'e yakinsa DSO tanimi KANONIK olur (capraz-kontrol gecti)"
