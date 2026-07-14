#!/usr/bin/env bash
# SAHA_KESIF_2 — ilk kesif HAFIZAMDAKI IKI SEYI CURUTTU:
#   ✗ /api/saha/musteri-destek/(\d+)/log diye bir rota YOK.
#   ✗ 403 (28233) PUT'un icinde (28224), GET'in (28147) degil.
#     Ama Eftal'in 403'leri GET'e geldi. Demek BASKA bir kapidan geliyor.
# Yamayi bu iki soru cevaplanmadan yazmam.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) GET musteri detay + PUT — 28140..28290 ARASI HAM KOD ############"
sed -n '28140,28290p' server_container.mjs | cat -n | sed 's/^/    /' | awk '{ $1 = $1 + 28139; print }' | head -0
awk 'NR>=28140 && NR<=28290 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 2) ⚠ EFTAL'IN 403'U NEREDEN? saha bolgesindeki TUM 403'ler ############"
awk 'NR>=27780 && NR<=31400 && /403/ { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 3) requireSahaAccess — kapi burada mi? ############"
grep -n "async function requireSahaAccess\|function requireSahaAccess" server_container.mjs
S=$(grep -n "function requireSahaAccess" server_container.mjs | head -1 | cut -d: -f1)
awk -v s="$S" 'NR>=s && NR<=s+45 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 4) musteri-destek GET/POST — 500'un tam yeri (30895..30960) ############"
awk 'NR>=30895 && NR<=30960 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 5) saha_hata_log — sutun adlari (created_at yokmus) ############"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='saha_hata_log' ORDER BY ordinal_position;"

echo
echo "⚠ CIKTIYI BANA YAPISTIR."
