#!/usr/bin/env bash
# ODA_YAPISI — Finans odasini kurmadan once MEVCUT DILI ogreniyorum.
#
# ⚠ "Bugun" ve "Veri" odalarini kurarken belirledigimiz ilkeler vardi:
#   · Her sayinin yaninda KOKEN (kaynak, formul, varsayim, SINIR, guven)
#   · Her sayinin yaninda ITIRAZ dugmesi — sistem sayiyi SAVUNMAZ, KAYNAGINI ACAR
#   · Sayiya tiklayinca beyin degil KOKEN PANELI acilir
#   · Her sayi "neden?" ve "ne yapabiliriz?" sorularini cevaplar
#   · tema.css tokenlari — iki tema, tek token seti
#
# ⚠ Yeni odayi AYNI DILLE kurmaliyim, yoksa iki farkli uygulama olur.
#   Hafizamdan yazarsam tutmaz. DOSYADAN okuyorum.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ODALAR — bi.js'de hangileri tanimli? ############"
grep -n "ODALAR\|const ODA\|rooms\s*=\|room:\s*['\"]" shells/bi.js | head -10
grep -n "\"bugun\"\|'bugun'\|\"veri\"\|'veri'" shells/bi.js | head -8

echo
echo "############ 2) BUGUN odasi — kurulus fonksiyonu (ilk 60 satir) ############"
L=$(grep -n "function vBugun\|const vBugun\|function odaBugun" shells/bi.js | head -1 | cut -d: -f1)
[ -n "$L" ] && awk -v s="$L" 'NR>=s && NR<=s+55 { printf "%5d| %s\n", NR, $0 }' shells/bi.js \
  || grep -n "bugun" shells/bi.js | head -10

echo
echo "############ 3) ⚠ KOKEN PANELI — sayiya tiklayinca ne oluyor? ############"
grep -n "koken\|kokenPanel\|sayiKoken\|data-anahtar" shells/bi.js | head -12

echo
echo "############ 4) ⚠ ITIRAZ — dugme ve akis ############"
grep -n "itiraz" shells/bi.js | head -10

echo
echo "############ 5) bi_sayi_koken — kayitli sayilar (Finans icin ne var?) ############"
$PSQL -c "SELECT anahtar, left(kaynak,40) AS kaynak, left(sinir,50) AS SINIR, guven
          FROM bi_sayi_koken ORDER BY anahtar;" 2>/dev/null | head -25

echo
echo "############ 6) /api/bi/ana — su an ne donduruyor? (Finans bunun uzerine kurulacak) ############"
grep -n "sermaye\|netrisk\|odemeler\|marj\|sinyaller\|vardiya" server_container.mjs | sed -n '1,3p'
awk 'NR>=23795 && NR<=23812 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 7) TEMA — hangi tokenlar var? ############"
ls -la tema.css 2>/dev/null && grep -n "^\s*--" tema.css | head -20 || echo "  (tema.css bulunamadi)"
