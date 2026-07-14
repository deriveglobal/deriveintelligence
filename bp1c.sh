echo "=== 'saha' gecen route benzeri satirlar ==="
grep -nE "pathname.*saha|saha.*pathname" server_container.mjs | head -10
echo
echo "=== ROUTE TANIMI HANGI KALIPLA YAZILIYOR (ornekler) ==="
grep -nE "request\.method === '(GET|POST|PUT|DELETE)'" server_container.mjs | head -8
echo
echo "=== BASKA BIR ESLESME KALIBI VAR MI ==="
grep -oE "p === '[^']+'|path === '[^']+'|pathname\.match\([^)]+\)|routes\[" server_container.mjs | sort -u | head -30
echo
echo "=== HANDLER FONKSIYONLARI ==="
grep -oE "async function _handle[A-Za-z]+|function handle[A-Za-z]+" server_container.mjs | sort -u
