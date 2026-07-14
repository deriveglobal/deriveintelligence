#!/usr/bin/env bash
# DONMUS_SAYI_AVI — Fatih dogru soruyu sordu: "hicbir sey sabit degil, degil mi?"
#
# ⚠ DURUST CEVAP: HAYIR.
#   SAYILAR hesaplaniyor (stok, alacak, borc, net, marj, DSO, durum, risk, takvim).
#   AMA ACIKLAMA METINLERI DONMUS SAYILAR ICERIYOR.
#
# ⚠ VE BU, SAYININ YANLIS OLMASINDAN DAHA SINSI:
#   Kimse bir aciklama metnine bakip "acaba bu guncel mi?" diye sormaz.
#   Ornek: "MUTAFLAR brut 47,6M ama borcumuz 46,6M, net 1,0M" — bi.js'de SABIT.
#   MUTAFLAR yarin borcunu kapatsa, ekran HALA ayni seyi yazacak.
#   Koken metinleri: "209,3M", "145,4M", "533 musteri", "%62", "12 Tem" — hepsi SABIT.
#   Bir ay sonra bunlar YALAN olacak.
#
# ⚠ Bugun butun gun "sistem yalan soyluyor" diye kovaladik.
#   Bu, GELECEKTE yalan soylemeye PROGRAMLANMIS bir katman.
#
# Sadece OKUR + LISTELER.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ ARAYUZ — metne gomulu sayilar (bi.js) ############"
echo "  (M / milyon / % / 'kat' / gun iceren SABIT metinler)"
grep -n "[0-9]\+[,.][0-9]\+M\|%[0-9]\+\|[0-9]\+ kat\|[0-9]\+ gün\|[0-9]\+ müşteri" shells/bi.js \
  | grep -v "_M(\|_tl(\|toFixed\|Number(\|round(\|Math\." \
  | grep -v "^\s*[0-9]*:\s*//" | head -25

echo
echo "############ 2) ⚠ KOKEN METINLERI — donmus sayilar ############"
$PSQL -c "
SELECT anahtar,
       (length(sinir) - length(regexp_replace(sinir, '[0-9]', '', 'g'))) AS rakam_adedi,
       left(sinir, 90) AS sinir
  FROM bi_sayi_koken
 WHERE sinir ~ '[0-9]'
 ORDER BY 2 DESC;"
echo "  ⚠ 'rakam_adedi' yuksek olan koken metinleri, bir ay sonra YALAN olacak."

echo
echo "############ 3) ⚠ SUNUCU — SQL/metin icinde sabit sayilar ############"
grep -n "0\.40\|\* 0\.4\b\|8\.1\|8\.3\|CURRENT_DATE-90\|CURRENT_DATE - 90\|365\b" server_container.mjs \
  | grep -iv "//\|--" | head -15

echo
echo "############ 4) ⚠ MOTOR — erp_ingest.py sabitleri ############"
grep -n "8\.1\|8\.3\|referans\|> 3\b\|2e6\|1e6\|<= 1000\|> 1000" erp_ingest.py | grep -v "^\s*#" | head -12

echo
echo "############ 5) ⚠ SINYAL MOTORU — esikler ############"
awk '/"sinyal_kredi"/,/"""/ { if ($0 ~ /2e6|1000|1\.5|90|365/) printf "%5d| %s\n", NR, $0 }' erp_ingest.py

echo
echo "############ 6) ⚠ BRISA ODEME TAKVIMI — nereden geliyor? ############"
echo "  (Ekranda 18 Kas / 16 Ara / 22 Oca / 22 Sub yaziyor. Bu tarihler NEREDEN?)"
grep -rn "2026-11-18\|18 Nov\|Brisa 1. dönem\|donem\", \"1\"" --include=*.py --include=*.mjs . 2>/dev/null \
  | grep -v "bak_\|srv_broken" | head -6
$PSQL -c "SELECT anahtar, tur, son_tarih, left(ozet,50) FROM bi_sinyal WHERE tur='odeme' ORDER BY son_tarih;"
echo "  ⚠ Bu sinyalleri KIM uretiyor? Elle mi girildi, hesaplaniyor mu?"
echo "     Elle girildiyse: Brisa bir taksiti degistirdiginde EKRAN YALAN SOYLER."

echo
echo "############ ⚠ HUKUM ############"
echo "  SAYILAR canli. HIKAYE donmus."
echo "  Yapilacak: (a) metindeki sayilari degiskene cevir"
echo "             (b) koken SINIR metinlerini sayidan ARINDIR — sinir bir KURAL olmali, bir OLCUM degil"
echo "             (c) %40 sermaye maliyeti gibi VARSAYIMLARI ayara tasi ve 'bu bir varsayim' de"
echo "             (d) Brisa takvimini elle giriliyorsa: kaynagini ekranda YAZ"
