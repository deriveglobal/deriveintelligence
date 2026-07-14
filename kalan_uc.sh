#!/usr/bin/env bash
# KALAN_UC — 15 temizlendi, 3 KALDI. "Sifir" demeden bitirmem.
#
# ⚠ Sayaç LINE sayiyor. Kalan 3 satir YORUM olabilir (zararsiz) ya da
#   GORUNUR METIN olabilir (hala yalan). Fark, her sey demek.
set -uo pipefail
cd /opt/krb-assessment

echo "############ KALAN 3 SATIR — nerede, gorunur mu? ############"
grep -n "203M\|104M\|116 gün\|131 gün\|282,4M\|268,5M\|47,6M\|46,6M\|Sailun −%40" shells/bi.js \
  | while IFS=: read -r no rest; do
      t=$(echo "$rest" | sed 's/^[[:space:]]*//')
      if [[ "$t" == //* || "$t" == /\** || "$t" == \** ]]; then
        echo "  $no  [YORUM — zararsiz, kullanici GORMEZ]"
      else
        echo "  $no  ⚠ [GORUNUR METIN — HALA YALAN]"
      fi
      echo "        ${t:0:120}"
    done

echo
echo "############ AYNI TARAMA — server_container.mjs (asistan sablonlari) ############"
grep -n "203M\|104M\|116 gün\|282,4M\|268,5M\|47,6M\|8,3\|MUTAFLAR" server_container.mjs \
  | grep -v "^\s*[0-9]*:\s*//" | head -10

echo
echo "############ ⚠ ASISTANIN SISTEM PROMPTU — sabit sayi var mi? ############"
echo "  (CEO Asistani bu metni HER SORUDA okuyor. Icindeki sabit sayi, HER CEVABA sizar.)"
grep -n "buildDeptSystemPrompt\|_buildBrainPrompt\|DB_SCHEMA\|kpiContext" server_container.mjs | head -6
L=$(grep -n "const DB_SCHEMA" server_container.mjs | head -1 | cut -d: -f1)
[ -n "$L" ] && awk -v s="$L" 'NR>=s && NR<=s+40 { if ($0 ~ /[0-9]+[,.][0-9]+M|%[0-9]|MUTAFLAR|203|104|116/) printf "%5d| %s\n", NR, substr($0,1,120) }' server_container.mjs
echo "  (bos ise: asistan promptunda sabit sayi YOK ✅)"
