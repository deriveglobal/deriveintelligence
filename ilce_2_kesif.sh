#!/usr/bin/env bash
# ILCE_2_KESIF — SADECE OKUR. iki soru:
#   1) ym- formu DUZENLEMEDE de kullaniliyor mu? il onceden dolunca ilce doluyor mu?
#   2) lok-ilce (satir 1952) serbest <input> — hangi ekran, kullanici onu mu goruyor?
set -u
cd /opt/krb-assessment || exit 1
SJ=shells/saha.js

echo "############ 1) il->ilce dinleyicisi TAM METNI (850-895) ############"
sed -n '848,895p' "$SJ" | nl -ba -v848 | sed 's/^/  /'

echo
echo "############ 2) ⚠ ym- formu DUZENLEMEDE onceden doluyor mu? ############"
echo "  --- 'ym-il' / 'ym-ilce' .value = (onceden doldurma) ---"
grep -n 'ym-il").value\|ym-ilce").value\|ym-il"\)\.value\|getElementById("ym-il")\.value =\|ym-il.*\.value =' "$SJ" | sed 's/^/  /'
echo "  --- formu acan fonksiyon(lar): yeniMusteri / musteriDuzenle / duzenle ---"
grep -n 'function.*[Mm]usteri.*[Mm]odal\|yeniMusteriModal\|musteriDuzenle\|musteriEkle\|function ymAc\|ym-il' "$SJ" | head -20 | sed 's/^/  /'

echo
echo "############ 3) ⚠ VAR OLAN musteri DUZENLENIYOR mu — ym formu mu? ############"
echo "  --- 'düzenle' / 'Düzenle' butonu musteri kartinda ---"
grep -n 'Düzenle\|düzenle\|musteriDuzenle\|editMusteri' "$SJ" | head -15 | sed 's/^/  /'

echo
echo "############ 4) ⚠ lok-il / lok-ilce — HANGI EKRAN? (serbest input) ############"
LOK=$(grep -n 'id="lok-il"' "$SJ" | head -1 | cut -d: -f1)
echo "  lok-il satiri: $LOK"
[ -n "${LOK:-}" ] && sed -n "$((LOK-25)),$((LOK+8))p" "$SJ" | nl -ba -v$((LOK-25)) | sed 's/^/  /'

echo
echo "############ 5) ⚠ lok- formunu acan fonksiyon ne? baslik ne? ############"
grep -n 'lok-ad\|lok-il\|Lokasyon\|lokasyon.*[Mm]odal\|Konum\|Adres ekle\|Yeni konum\|Şube' "$SJ" | head -20 | sed 's/^/  /'

echo
echo "############ SONUC — kullanici HANGI ekrani goruyor? ############"
echo "  ⚠ Eftal genelde YENI MUSTERI ya da MUSTERI DUZENLE kullanir."
echo "  ⚠ ym-ilce zaten <select>. Sorun ya (a) duzenlemede il dolu ama ilce bos kaliyor,"
echo "     ya (b) kullanici lok- (lokasyon/sube) formundaki serbest ilce'yi goruyor."
