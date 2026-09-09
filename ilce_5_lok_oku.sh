#!/usr/bin/env bash
# ILCE_5_LOK_OKU — SADECE OKUR. lok- formunu acilir yapmadan once ANKRAJLARI gor.
#   1) lok-il / lok-ilce <input> HTML'i (input->select icin)
#   2) lok-ekle click handler'i NEREDE baglaniyor (dinleyici oraya girecek)
#   3) modal render sonrasi hangi fonksiyon calisiyor
set -u
cd /opt/krb-assessment || exit 1
SJ=shells/saha.js

echo "############ 1) lok- form HTML — tam satirlar ############"
grep -n 'id="lok-ad"\|id="lok-il"\|id="lok-ilce"\|id="lok-ekle"' "$SJ" | sed 's/^/  /'
echo
echo "  --- lok-il / lok-ilce cevresi ---"
L=$(grep -n 'id="lok-il"' "$SJ" | head -1 | cut -d: -f1)
sed -n "$((L-3)),$((L+5))p" "$SJ" | nl -ba -v$((L-3)) | sed 's/^/  /'

echo
echo "############ 2) lok-ekle HANDLER — nerede baglaniyor? ############"
grep -n 'lok-ekle\|lok-il\|lok-ilce\|lok-ad\|lok-liste' "$SJ" | sed 's/^/  /'

echo
echo "############ 3) ⚠ handler'in TAM govdesi (dinleyici buraya girecek) ############"
H=$(grep -n 'getElementById("lok-ekle")' "$SJ" | head -1 | cut -d: -f1)
if [ -n "${H:-}" ]; then
  echo "  lok-ekle handler satiri: $H"
  sed -n "$((H-4)),$((H+30))p" "$SJ" | nl -ba -v$((H-4)) | sed 's/^/  /'
else
  echo "  ⚠ getElementById(\"lok-ekle\") bulunamadi — baska sekilde baglaniyor olabilir"
  grep -n 'lok-ekle' "$SJ" | sed 's/^/  /'
fi

echo
echo "############ 4) ⚠ musteriDetayModal — modal() render'i nerede biter, handler nerede baslar? ############"
M=$(grep -n 'function musteriDetayModal' "$SJ" | head -1 | cut -d: -f1)
echo "  musteriDetayModal: satir $M"
echo "  --- bu fonksiyon icinde 'addEventListener' ilk kullanimlari ---"
awk "NR>=$M && NR<=$((M+220)) && /addEventListener|getElementById\(\"lok/" {print NR\": \"\$0}" "$SJ" | head -20 | sed 's/^/  /'

echo
echo "############ SONUC ############"
echo "  ⚠ Bir sonraki adim: lok-il/lok-ilce input->select + dinleyici + ?v= bump."
echo "  ⚠ g('lok-il') .value okur — select'te de calisir. Reset (.value='') select'te ilk option'a doner."
