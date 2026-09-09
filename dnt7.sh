# Auth fonksiyon adlarini KODDAN cek, elle yazma
AUTH=$(grep -oE "require[A-Za-z]+\(|getSessionUser\(" server_container.mjs | tr -d '(' | sort -u | paste -sd'|')
echo "Kapinin bildigi auth fonksiyonlari: $AUTH"
echo

echo "############ AUTH'SUZ YAZMA UCLARI — TAM LISTE ############"
awk -v auth="$AUTH" '
  /(POST|PUT|PATCH|DELETE).*url\.pathname === / { rt=$0; ln=NR; look=25; found=0; next }
  look>0 {
    if ($0 ~ auth || /_ops_ok|INGEST_TOKEN|x-ingest-token|secret/) { found=1; look=0; next }
    look--
    if (look==0 && !found) { print "  ⚠ " ln ": " rt }
  }
' server_container.mjs

echo
echo "############ AUTH'SUZ OKUMA UCLARI (GET) ############"
awk -v auth="$AUTH" '
  /GET.*url\.pathname === / { rt=$0; ln=NR; look=25; found=0; next }
  look>0 {
    if ($0 ~ auth || /_ops_ok|secret/) { found=1; look=0; next }
    look--
    if (look==0 && !found) { print "  ⚠ " ln ": " rt }
  }
' server_container.mjs | head -20
