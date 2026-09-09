#!/usr/bin/env bash
# ILCE_3_CACHE — SADECE OKUR. Teori: saha.js SURUM numarasi hic degismedi,
#   tarayici eski dosyayi onbellekten calistiriyor. Onca deploy Eftal'e ULASMADI.
#
# ⚠ "il tamam, ilce serbest" -> ESKI form: il=datalist(oneri verir), ilce=<input>(serbest).
#   Yeni formda ikisi de <select>. Yani Eftal ESKI saha.js goruyor.
set -u
cd /opt/krb-assessment || exit 1

echo "############ 1) saha.js HANGI surumle import ediliyor? (app.js) ############"
grep -n 'shells/saha.js' app.js | sed 's/^/  /'
echo
echo "############ 2) app.js HANGI surumle yukleniyor? (index.html) ############"
grep -n 'app.js' index.html | sed 's/^/  /'
echo
echo "############ 3) ⚠ shells/*.js CACHE header'i ne? (uzun cache = sorun) ############"
echo "  --- GET /shells/saha.js response headers ---"
curl -sI "http://localhost:8080/shells/saha.js" | grep -iE 'cache-control|etag|last-modified|expires' | sed 's/^/  /'
echo "  --- GET /app.js response headers ---"
curl -sI "http://localhost:8080/app.js" | grep -iE 'cache-control|etag|last-modified|expires' | sed 's/^/  /'
echo "  --- GET / (index.html) response headers ---"
curl -sI "http://localhost:8080/" | grep -iE 'cache-control|etag|last-modified|expires' | sed 's/^/  /'

echo
echo "############ 4) ⚠ saha.js versiyon stringinin GECMISI — hic degisti mi? ############"
echo "  --- saha.js?v= gecen TUM yerler (app.js + index.html + backup) ---"
grep -rn 'saha\.js?v=' app.js index.html 2>/dev/null | sed 's/^/  /'
echo
echo "  ⚠ Bugun saha.js'i defalarca deploy ettim. Eger ?v= hep '20260707-18' ise:"
echo "     tarayici HICBIRINI gormedi. Import satiri, acilir liste, tr_il_ilce — hepsi karanlik."

echo
echo "############ 5) app.js icindeki DIGER shell surumleri (tutarli mi?) ############"
grep -oE '/shells/[a-z_]+\.js\?v=[0-9-]+' app.js | sort -u | sed 's/^/  /'

echo
echo "############ SONUC ############"
echo "  ⚠ Cozum: app.js icindeki saha.js ?v='i BUMP et + index.html icindeki app.js ?v='i BUMP et."
echo "     index.html taze gelir -> yeni app.js -> yeni saha.js -> tr_il_ilce yuklenir."
echo "  ⚠ AYRICA: lok- (Lokasyon Ekle) formundaki il/ilce hala serbest — onu da acilir yapacagim."
