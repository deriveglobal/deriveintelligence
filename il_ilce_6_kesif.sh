#!/usr/bin/env bash
# IL_ILCE_6_KESIF — SADECE OKUR. Hicbir sey degistirmez.
#
# ⚠ SORUN: il_ilce_5 "saha.js script etiketi bulunamadi" dedi ve ATLADI.
#   Yani /shells/tr_il_ilce.js sunucuda DURUYOR (HTTP 200) ama HIC KIMSE YUKLEMIYOR.
#   window.TR_ILLER_RESMI tanimsiz -> acilir liste BOS gelir.
#
# ⚠ VE keşif sunu gosterdi: saha.js:5822'de KENDI TR_ILLER dizisi var.
#   Ekranda zaten bir il listesi vardi. Nereden geliyordu? OKUYACAGIM.
#
# ⚠ TAHMIN ETMIYORUM. saha.js'in tarayiciya NASIL ulastigini bulacagim.
set -uo pipefail
cd /opt/krb-assessment || exit 1

echo "############ 1) saha.js DISKTE nerede? ############"
find /opt/krb-assessment -name 'saha.js' -not -path '*/node_modules/*' 2>/dev/null | while read -r f; do
  echo "  $f  ($(wc -l < "$f") satir)"
done

echo
echo "############ 2) HTML dosyalari — hangileri var? ############"
find /opt/krb-assessment -maxdepth 2 -name '*.html' -not -path '*/node_modules/*' 2>/dev/null | while read -r f; do
  echo "  --- $f ---"
  grep -n '<script' "$f" | sed 's/^/      /'
done

echo
echo "############ 3) ⚠ saha.js kelimesi NEREDE geciyor? (sunucu + html) ############"
grep -rn "saha\.js" /opt/krb-assessment --include='*.mjs' --include='*.html' --include='*.js' \
  --exclude-dir=node_modules 2>/dev/null | head -30 | sed 's/^/  /'

echo
echo "############ 4) ⚠ shells/ NASIL SERVIS EDILIYOR? ############"
grep -n "shells" server_container.mjs | head -20 | sed 's/^/  /'

echo
echo "############ 5) ⚠ SAHA SAYFASI HTML'i — sunucuda uretiliyor olabilir ############"
echo "  --- 'shells/' iceren script etiketleri (server_container.mjs icinde) ---"
grep -n 'script src=' server_container.mjs | head -30 | sed 's/^/  /'

echo
echo "############ 6) tr_il_ilce.js gercekten shells/ icinde mi? ############"
ls -la /opt/krb-assessment/shells/ | sed 's/^/  /'

echo
echo "############ 7) ⚠ saha.js:5822 — ESKI TR_ILLER dizisi ############"
SJ=$(find /opt/krb-assessment -name 'saha.js' -not -path '*/node_modules/*' | head -1)
echo "  dosya: $SJ"
sed -n '5818,5830p' "$SJ" | nl -ba -v5818 | sed 's/^/  /'
echo
echo "  --- TR_ILLER kac yerde kullaniliyor? ---"
grep -n 'TR_ILLER' "$SJ" | sed 's/^/  /'
echo
echo "  --- TR_ILLER_RESMI / TR_IL_ILCE (yeni) kac yerde? ---"
grep -n 'TR_ILLER_RESMI\|TR_IL_ILCE' "$SJ" | sed 's/^/  /'

echo
echo "############ 8) ⚠ CANLI KONTROL — tarayici ne goruyor? ############"
echo "  --- GET / iceriginde tr_il_ilce gecıyor mu? ---"
if curl -s http://localhost:8080/ | grep -q 'tr_il_ilce'; then
  echo "      ✅ EVET — sayfa dosyayi yukluyor"
else
  echo "      ❌ HAYIR — sayfa dosyayi YUKLEMIYOR. Acilir liste BOS gelir."
fi
echo "  --- GET / iceriginde saha.js geciyor mu? ---"
curl -s http://localhost:8080/ | grep -o '<script[^>]*>' | head -20 | sed 's/^/      /'

echo
echo "############ 9) ⚠ tr_il_ilce.js icerigi saglam mi? ############"
curl -s http://localhost:8080/shells/tr_il_ilce.js | head -c 200 | sed 's/^/  /'
echo
echo "  --- son satirlar (window.* atamalari) ---"
curl -s http://localhost:8080/shells/tr_il_ilce.js | tail -8 | sed 's/^/  /'

echo
echo "############ SONUC ############"
echo "  ⚠ 8) HAYIR diyorsa: dosya sunucuda ama sayfada YOK. Baglantiyi kuracagim."
echo "  ⚠ 7) eski TR_ILLER hala kullaniliyorsa: iki liste var demektir. Biri olmeli."
