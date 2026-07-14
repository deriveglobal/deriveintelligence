#!/usr/bin/env bash
# BIJS_CAPA — Finans ekranini yazmadan once bi.js'nin GERCEK yapisi. Sadece OKUR.
# ⚠ Bugun BES KEZ hafizadan capa yazip yanildim. Altincisi olmayacak.
set -uo pipefail
cd /opt/krb-assessment

echo "############ A) SEKME CUBUGU (78-95) ############"
awk 'NR>=78 && NR<=95 { printf "%4d| %s\n", NR, $0 }' shells/bi.js

echo
echo "############ B) ODA OLUSTURMA — bugun (215-245) ############"
awk 'NR>=215 && NR<=245 { printf "%4d| %s\n", NR, $0 }' shells/bi.js

echo
echo "############ C) ODA OLUSTURMA — veri (608-640) ############"
awk 'NR>=608 && NR<=640 { printf "%4d| %s\n", NR, $0 }' shells/bi.js

echo
echo "############ D) TIKLAMA + KOKEN + ITIRAZ (505-600) ############"
awk 'NR>=505 && NR<=600 { printf "%4d| %s\n", NR, $0 }' shells/bi.js

echo
echo "############ E) SEKME DEGISIMI (760-800) ############"
awk 'NR>=760 && NR<=800 { printf "%4d| %s\n", NR, $0 }' shells/bi.js

echo
echo "############ F) KART/SAYI CSS SINIFLARI — hangi siniflar var? ############"
grep -o "class=\"[a-z0-9 -]*\"" shells/bi.js | sort | uniq -c | sort -rn | head -20
echo
echo "  --- 'kart', 'dn', 'n-buyuk', 'd-sari' gibi siniflar tema.css'te tanimli mi? ---"
grep -n "\.kart\|\.dn\b\|\.n-buyuk\|\.n-orta\|\.d-sari\|\.d-yesil\|\.d-kirmizi\|\.vmo-tab" tema.css | head -12
