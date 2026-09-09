#!/usr/bin/env bash
# ILCE_1_KESIF — SADECE OKUR. ilce neden hala serbest giris?
#
# ⚠ 5. adim "ym-ilce -> bagimli SELECT" dedi. Kullanici "hala serbest giris" diyor.
#   Ikisinden biri yaniliyor. SERVIS EDILEN dosyaya bakacagim — diske degil.
set -u
cd /opt/krb-assessment || exit 1
SJ=shells/saha.js

echo "############ 1) ym-il ve ym-ilce — SERVIS EDILEN saha.js'te ne? ############"
curl -s http://localhost:8080/shells/saha.js > /tmp/live_saha.js
echo "  --- ym-il satiri ---"
grep -n 'ym-il"' /tmp/live_saha.js | sed 's/^/  /'
echo "  --- ym-ilce satiri ---"
grep -n 'ym-ilce"' /tmp/live_saha.js | sed 's/^/  /'
echo
echo "  --- ym-il / ym-ilce ETRAFI (context) ---"
awk '/id="ym-il"/{f=NR} /id="ym-ilce"/{g=NR} END{}' /tmp/live_saha.js
IL_LN=$(grep -n 'id="ym-il"' /tmp/live_saha.js | head -1 | cut -d: -f1)
if [ -n "${IL_LN:-}" ]; then
  echo "  (ym-il satiri: $IL_LN — cevresi:)"
  sed -n "$((IL_LN-2)),$((IL_LN+12))p" /tmp/live_saha.js | nl -ba -v$((IL_LN-2)) | sed 's/^/  /'
fi

echo
echo "############ 2) ⚠ ym-ilce <input> mu <select> mi? ############"
if grep -q 'id="ym-ilce"[^>]*class="giris"' /tmp/live_saha.js && grep 'ym-ilce' /tmp/live_saha.js | grep -q '<input'; then
  echo "  ❌ hala <input> — SERBEST GIRIS"
fi
echo "  --- ym-ilce iceren ham satir(lar) ---"
grep -o '<[^>]*ym-ilce[^>]*>' /tmp/live_saha.js | sed 's/^/  /'
grep -o '<select[^>]*ym-ilce[^>]*>' /tmp/live_saha.js | sed 's/^/  SELECT? /'
grep -o '<input[^>]*ym-ilce[^>]*>' /tmp/live_saha.js | sed 's/^/  INPUT?  /'

echo
echo "############ 3) ⚠ il->ilce bagimlilik dinleyicisi VAR MI? ############"
grep -n 'TR_IL_ILCE' /tmp/live_saha.js | sed 's/^/  /'
echo "  --- ym-il change dinleyicisi ---"
grep -n "getElementById(\"ym-il\")\|ym-il').*addEventListener\|ym-il\").*addEventListener\|change.*ym-il\|ym-il.*change" /tmp/live_saha.js | sed 's/^/  /'

echo
echo "############ 4) ⚠ FORM KAC YERDE? — belki BASKA bir ilce girisi var ############"
echo "  --- 'ilce' gecen tum input/select id'leri ---"
grep -o 'id="[a-z0-9-]*ilce[a-z0-9-]*"' /tmp/live_saha.js | sort -u | sed 's/^/  /'
grep -o 'id="[a-z0-9-]*il"' /tmp/live_saha.js | sort -u | sed 's/^/  /'

echo
echo "############ 5) ⚠ MUSTERI DUZENLE formu — ayri olabilir ############"
echo "  --- 'İlçe' etiketi gecen yerler ---"
grep -n 'İlçe\|Ilce\|ilçe' /tmp/live_saha.js | head -20 | sed 's/^/  /'

echo
echo "############ SONUC ############"
echo "  ⚠ 2) <input> diyorsa: 5. adim yamasi TUTMAMIS ya da BASKA forma bakiyoruz."
echo "  ⚠ 4/5) birden fazla ilce girisi varsa: biri select, biri hala serbest olabilir."
