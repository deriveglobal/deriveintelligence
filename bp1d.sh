echo "=== SAHA UCLARI (handleSahaApi icinde) ==="
sed -n '21022,22150p' server_container.mjs | grep -oE '"/api/saha/[^"]*"' | tr -d '"' | sort -u
echo
echo "=== SAHA UC SAYISI ==="
sed -n '21022,22150p' server_container.mjs | grep -cE '"/api/saha/'
echo
echo "=== handleSahaApi NEREDE BITIYOR ==="
grep -n "function handleSahaApi\|function handleApi\|function handleItChatWithTools" server_container.mjs
echo
echo "=== ROL ASISTANLARI (department) ==="
grep -nE "department/\(sales\|pricing" server_container.mjs | head -3
echo
echo "=== ASISTAN ARACLARI (tool tanimlari) ==="
grep -oE "name: '[a-z_]+'" server_container.mjs | sort -u | head -40
