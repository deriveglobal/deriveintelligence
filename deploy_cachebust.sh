#!/usr/bin/env bash
# CACHEBUST — WKWebView (iOS) sabit ?v=20260714-2 yüzünden saha.js'i tazelemiyordu. index.html'deki
# app.js sürümü + app.js'deki saha.js import sürümü zaman damgasına yükseltilir → telefon taze çeker.
# Bu deploy TÜM birikmiş saha.js düzeltmelerini (konum/durum/ebat/padding/textsize) telefona ulaştırır.
set -e
cd /opt/krb-assessment
VER=$(date +%Y%m%d-%H%M)
echo "yeni sürüm: $VER"

IDX=$(grep -rlE 'app\.js\?v=' --include='*.html' . 2>/dev/null | grep -vE 'node_modules|/backups/' | head -1)
APPJS=$(grep -rlE '/shells/saha\.js\?v=' . 2>/dev/null | grep -vE 'node_modules|/backups/' | head -1)
[ -n "$IDX" ] && [ -f "$IDX" ] || { echo "HATA: index.html (app.js?v=) bulunamadı"; exit 1; }
[ -n "$APPJS" ] && [ -f "$APPJS" ] || { echo "HATA: app.js (saha.js?v=) bulunamadı"; exit 1; }
echo "index: $IDX"; echo "app.js: $APPJS"

cp "$IDX" "$IDX.bak.$(date +%s)"; cp "$APPJS" "$APPJS.bak.$(date +%s)"
echo "== ÖNCE =="
grep -oE 'app\.js\?v=[0-9A-Za-z._-]+' "$IDX" | head -1
grep -oE '/shells/saha\.js\?v=[0-9A-Za-z._-]+' "$APPJS" | head -1

sed -i -E "s#(app\.js\?v=)[0-9A-Za-z._-]+#\1${VER}#g" "$IDX"
sed -i -E "s#(/shells/saha\.js\?v=)[0-9A-Za-z._-]+#\1${VER}#g" "$APPJS"

echo "== SONRA =="
grep -oE 'app\.js\?v=[0-9A-Za-z._-]+' "$IDX" | head -1
grep -oE '/shells/saha\.js\?v=[0-9A-Za-z._-]+' "$APPJS" | head -1

docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
sleep 4
echo "== konteyner doğrulama =="
docker exec krb-assessment sh -c "grep -oE 'app\.js\?v=[0-9A-Za-z._-]+' /app/index.html | head -1" || true
docker exec krb-assessment sh -c "grep -oE '/shells/saha\.js\?v=[0-9A-Za-z._-]+' /app/app.js | head -1" || true
echo "== DONE — telefonda uygulamayı TAMAMEN kapatıp aç =="
