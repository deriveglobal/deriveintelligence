#!/usr/bin/env bash
# ⚠ YAMA YOK. Tema nereye enjekte edilecek, GORMEDEN dokunmuyorum.
#   Bugun uc kez ezberden kolon/anchor yazdim, uçu de patladi.
set -uo pipefail
cd /opt/krb-assessment

echo "════════ 1) HER IKI SHELL — CSS nerede basliyor? ════════"
for F in shells/bi.js shells/saha.js; do
  echo "── $F ($(wc -l < $F) satir, $(du -h $F | cut -f1)) ──"
  grep -n "<style>\|</style>\|:root\s*{\|--bg-0\|--zemin\|font-family" "$F" | head -8
  echo
done

echo "════════ 2) ⚠ MEVCUT PALET — ne silinecek? ════════"
echo "── bi.js: gradient / golge / glow var mi? ──"
grep -c "linear-gradient\|box-shadow\|backdrop-filter\|blur(" shells/bi.js
echo "── saha.js: ──"
grep -c "linear-gradient\|box-shadow\|backdrop-filter\|blur(" shells/saha.js

echo
echo "════════ 3) ⚠ FONT AGIRLIGI — kac yerde 600/700 var? ════════"
echo "  bi.js:   $(grep -c 'font-weight:\s*[67]00\|font-weight:\s*bold' shells/bi.js)"
echo "  saha.js: $(grep -c 'font-weight:\s*[67]00\|font-weight:\s*bold' shells/saha.js)"

echo
echo "════════ 4) ⚠⚠ VIEWPORT META — mobil hazir mi? ════════"
grep -n "viewport" shells/bi.js shells/saha.js | head -4
echo "  ^ 'width=device-width, initial-scale=1' YOKSA telefonda masaustu gibi kucultulur."

echo
echo "════════ 5) ⚠⚠ TABLO SAYISI — mobilde karta cevrilecek ════════"
echo "  bi.js   <table>: $(grep -c '<table' shells/bi.js)"
echo "  saha.js <table>: $(grep -c '<table' shells/saha.js)"

echo
echo "════════ 6) STATIK DOSYA SUNULUYOR MU? (tema.css icin) ════════"
grep -n "\.css\|text/css\|static\|public/" server_container.mjs | head -8

echo
echo "════════ 7) SHELL'LER NASIL SUNULUYOR? ════════"
grep -n "shells/bi\|shells/saha\|readFileSync.*shell" server_container.mjs | head -6
