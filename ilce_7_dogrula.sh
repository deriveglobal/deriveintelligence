#!/usr/bin/env bash
# ILCE_7_DOGRULA — SADECE OKUR. "/" GERCEKTEN app.js'i yeni surumle yukluyor mu?
#   D) bolumunde index.html app.js surumu BOS dondu. Neden?
set -u
cd /opt/krb-assessment || exit 1

echo "############ 1) '/' NE SERVIS EDIYOR? — app.js referansi var mi? ############"
echo "  --- served '/' icinde app.js gecen satirlar ---"
curl -s http://localhost:8080/ | grep -n 'app\.js' | sed 's/^/  /'
echo "  --- served '/' icinde 'script' + 'src=' satirlari ---"
curl -s http://localhost:8080/ | grep -oE '<script[^>]*src="[^"]*"[^>]*>' | sed 's/^/  /'

echo
echo "############ 2) ⚠ served '/' hangi dosya? boyut + ilk satir ############"
echo "  served '/' byte: $(curl -s http://localhost:8080/ | wc -c)"
echo "  disk index.html byte: $(wc -c < index.html)"
echo "  --- served '/' ilk 3 satir ---"
curl -s http://localhost:8080/ | head -3 | sed 's/^/    /'
echo "  --- disk index.html ilk 3 satir ---"
head -3 index.html | sed 's/^/    /'

echo
echo "############ 3) ⚠ served '/' app.js surumu (BRE degil, sabit metin ara) ############"
echo -n "  served '/' app.js?v= : "
curl -s http://localhost:8080/ | grep -oF 'app.js?v=' >/dev/null && \
  curl -s http://localhost:8080/ | grep -o 'app\.js?v=[0-9-]*' | head -1 || echo "(app.js?v= YOK)"
echo -n "  disk index.html app.js?v= : "
grep -o 'app\.js?v=[0-9-]*' index.html | head -1

echo
echo "############ 4) ⚠ sunucu '/' rotasi — hangi dosyayi okuyor? ############"
grep -n 'index.html\|homepage.html\|readFile.*html\|"/"\s*)' server_container.mjs | grep -i html | head -15 | sed 's/^/  /'

echo
echo "############ 5) ⚠ KRITIK — app.js taze mi geliyor? (no-cache dogru mu) ############"
echo "  --- served app.js saha.js import surumu (ZATEN dogrulanmisti) ---"
curl -s http://localhost:8080/app.js | grep -o 'saha\.js?v=[0-9-]*' | head -1 | sed 's/^/    /'
echo
echo "  ⚠ MANTIK: index.html no-store (hep taze) -> app.js no-cache (yeniden ceker)"
echo "     -> app.js icinde saha.js?v=20260714-2 -> saha.js taze."
echo "     app.js surumu index'te eskimis olsa BILE, no-cache app.js'i tazeler."
echo "     Yani saha.js zinciri KOPMAZ. Ama index served degilse onu da bilmeliyim."

echo
echo "############ SONUC ############"
echo "  ⚠ 1/3 app.js?v= yeni ise: her sey yerinde."
echo "  ⚠ '/' index.html DEGILSE: served HTML hangi app.js'i yukluyor, ONU gorecegiz."
