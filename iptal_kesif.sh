#!/usr/bin/env bash
# IPTAL_KESIF — 'iptal' ZATEN VAR (saha.js:1129). Sifirdan yazmayacagim.
# ⚠ Muhtemelen sadece PLANLANAN ziyaretlerde gorunuyor. Eftal'in derdi TAMAMLANMIS bir kayitti.
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) SUNUCU — PUT action='iptal' ne yapiyor? ############"
L=$(grep -n 'method === "PUT" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/' server_container.mjs | head -1 | cut -d: -f1)
[ -n "$L" ] && awk -v s="$L" 'NR>=s && NR<=s+55 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 2) ARAYUZ — iptal butonu NEREDE gorunuyor? ############"
grep -n "iptal" shells/saha.js | head -15

echo
echo "############ 3) durum ENUM — hangi degerler izinli? ############"
$PSQL -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint
          WHERE conrelid='saha_ziyaret'::regclass AND contype='c';"
$PSQL -c "SELECT durum, count(*) FROM saha_ziyaret GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 4) SILME UC NOKTASI VAR MI? ############"
grep -n 'method === "DELETE".*ziyaret' server_container.mjs

echo
echo "############ 5) ZIYARET KARTI — hangi butonlar var? (liste gorunumu) ############"
grep -n "data-iptal\|data-duzenle\|✏️\|Düzenle" shells/saha.js | head -10
