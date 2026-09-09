echo "############ 1. CIFT TANIMLI ROUTE'LAR (mayin tarlasi) ############"
grep -oE "(GET|POST|PUT|DELETE|PATCH)' && url\.pathname === '[^']+'" server_container.mjs \
  | sed "s/' && url.pathname === '/ /" | tr -d "'" | sort | uniq -c | awk '$1>1' | sort -rn

echo
echo "############ 2. tid NEREDE TANIMLI (20981'i besleyen) ############"
awk 'NR>=20900 && NR<=20985 && /const tid|let tid|var tid|tid =/ {print NR": "$0}' server_container.mjs
echo "--- 20917 (bir onceki route) auth'u:"
sed -n '20917,20935p' server_container.mjs

echo
echo "############ 3. AUTH FONKSIYONLARININ TAMAMI ############"
grep -oE "require[A-Za-z]+\(|getSessionUser\(" server_container.mjs | sort | uniq -c | sort -rn

echo
echo "############ 4. AUTH'SUZ YAZMA UCLARI — DOGRU KAPI ############"
awk '
  /(POST|PUT|PATCH|DELETE).*url\.pathname === / { rt=$0; ln=NR; look=20; found=0; next }
  look>0 {
    if (/requireAuth|requireSahaAccess|requireBiDept|requireModuleAccess|requirePlatformOwner|getSessionUser|_ops_ok|secret/) { found=1; look=0; next }
    look--
    if (look==0 && !found) { print "  ⚠ " ln ": " rt }
  }
' server_container.mjs
