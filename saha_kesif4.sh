#!/usr/bin/env bash
# SAHA_KESIF_4 — SON. Cagirani gormeden yama yok.
#
# ⚠ KESIN OLAN: 403 mesaji ("Bu musteri size atanmamis.") kodda TEK yerde: 28233, PUT icinde.
#   Yani arayuz musteriyi ACARKEN degil, KAYDEDERKEN PUT atiyor. view_adi=ziyaretler.
#   Eftal baskasinin musterisini ZIYARET EDIYOR, ziyareti kaydediyor,
#   sistem musteri profilini guncellemeye kalkiyor ve reddediliyor. 13 kez.
#   Sunucudaki 403 DOGRU. Yanlis olan, arayuzun duzenleyebilecegini SANIP PUT atmasi.
#   Yamayi yanlis tarafa vurmamak icin CAGIRANI goruyorum.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) Frontend: musteriler/{id} PUT'u kim atiyor? ############"
grep -rn "saha/musteriler/" shells/ components/ *.js 2>/dev/null | grep -i "put\|method" | head -20
echo "--- PUT gecen tum satirlar (baglamli) ---"
grep -rn --include=*.js -B2 -A6 'method:\s*"PUT"' shells/saha*.js 2>/dev/null | grep -n "musteriler" -A4 -B6 | head -60

echo
echo "############ 2) hangi dosya? saha shell'i nerede ############"
ls -la shells/ | head -20

echo
echo "############ 3) ziyaret KAYDEDERKEN musteri profili guncelleniyor mu? ############"
grep -rn "sektorler\|tedarikci_markalar" shells/*.js | head -20

echo
echo "############ 4) JS_HATA: det-yorum-gonder ############"
grep -rn "det-yorum-gonder" shells/*.js components/*.js 2>/dev/null | head

echo
echo "############ 5) GET /api/saha/ziyaretler/{id} — arayuzde kim cagiriyor? ############"
grep -rn "saha/ziyaretler/\${" shells/*.js | head -10
