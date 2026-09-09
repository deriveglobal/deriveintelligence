#!/usr/bin/env bash
# ILCE_4_SW — SADECE OKUR. Service worker var mi? Sürüm artirma gercekten
#   yayin mekanizmasi mi? (bi.js bumped, saha.js degil — kanit mi?)
set -u
cd /opt/krb-assessment || exit 1

echo "############ 1) SERVICE WORKER kaydi var mi? ############"
grep -rn 'serviceWorker\|navigator\.serviceWorker\|register(' index.html app.js 2>/dev/null | head -20 | sed 's/^/  /'
echo
echo "  --- sw.js / service-worker.js dosyasi diskte var mi? ---"
find /opt/krb-assessment -maxdepth 2 -iname '*sw*.js' -o -maxdepth 2 -iname '*service-worker*' 2>/dev/null | grep -v node_modules | sed 's/^/  /'
ls -la /opt/krb-assessment/*.js 2>/dev/null | grep -iE 'sw|worker' | sed 's/^/  /'

echo
echo "############ 2) index.html satir 14 — krb-perm-obs NE YAPIYOR? ############"
sed -n '14,60p' index.html | sed 's/^/  /'

echo
echo "############ 3) ⚠ CACHE / caches.open / precache index.html+app.js icinde ############"
grep -n "caches\.\|cache\.addAll\|precache\|CACHE_NAME\|workbox" index.html app.js 2>/dev/null | head -20 | sed 's/^/  /'

echo
echo "############ 4) ⚠ KANIT — bi.js bump edilirken saha.js edilmedi mi? (git) ############"
if [ -d .git ]; then
  echo "  --- app.js icindeki ?v= satirlarinin git blame'i ---"
  git log --oneline -5 -- app.js 2>/dev/null | sed 's/^/  /'
  echo "  --- 'saha.js?v=' son ne zaman degisti? ---"
  git log -S 'saha.js?v=20260707-18' --oneline -3 -- app.js 2>/dev/null | sed 's/^/  /'
  echo "  --- 'bi.js?v=' son ne zaman degisti? ---"
  git log -S 'bi.js?v=20260708-03' --oneline -3 -- app.js 2>/dev/null | sed 's/^/  /'
else
  echo "  (git yok)"
fi

echo
echo "############ 5) app.js NASIL servis ediliyor — sunucu ?v='i onemsiyor mu? ############"
# ⚠ ?v= sadece TARAYICI/SW icin. Sunucu ayni dosyayi doner. Ama SW URL'ye gore keyler.
echo "  --- app.js icinde 'saha.js' import satirinin TAMAMI ---"
sed -n '12580,12590p' app.js | nl -ba -v12580 | sed 's/^/  /'

echo
echo "############ SONUC ############"
echo "  ⚠ SW VARSA: ?v= bump SART — SW eski saha.js'i URL'ye gore serviyor."
echo "  ⚠ SW YOKSA: no-cache yeterli, sorun cache DEGIL — o zaman kullanici lok- formunu goruyor."
echo "     Iki durumda da: (a) surumleri bump + (b) lok- formunu acilir yap."
