echo "=== A. bi_sayi_koken KODDA GECIYOR MU ==="
grep -n "bi_sayi_koken\|sayi_koken\|/api/koken\|kokenGetir" server_container.mjs || echo "(HIC GECMIYOR — tablo kodda okunmuyor)"
echo
echo "=== B. sermaye endpoint'inin BASI (24020-24072) ==="
sed -n '24020,24072p' server_container.mjs
echo
echo "=== C. query() imzasi ==="
grep -n "^async function query\|^function query\|const query = " server_container.mjs | head -5
echo
echo "=== D. KRB_COMPANY_PROFILE'in GORMEDIGIM ORTASI (25430-25466) ==="
sed -n '25430,25466p' server_container.mjs
echo
echo "=== E. 'kaynak' nesnesini FRONTEND tuketiyor mu ==="
grep -rn "\.kaynak\b\|kaynak\." --include=*.html --include=*.js --include=*.jsx . 2>/dev/null | grep -vi node_modules | head -20
echo
echo "=== F. itiraz dugmesi / koken ekrani var mi ==="
grep -n "itiraz\|koken" server_container.mjs | grep -i "api\|endpoint\|route" | head -10
