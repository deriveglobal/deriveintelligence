echo "############ 1. DOSYA ENVANTERI ############"
echo "--- kok dizin (dizinler haric)"
find . -maxdepth 1 -type f ! -name "*.yedek*" -printf "%8s  %p\n" | sort -rn | head -25
echo
echo "--- satir sayilari (kod dosyalari)"
wc -l server_container.mjs erp_ingest.py 2>/dev/null
echo
echo "--- shells/ (frontend)"
wc -l shells/*.js shells/*.html 2>/dev/null | sort -rn | head -20
echo
echo "--- components/"
ls -la components/ 2>/dev/null | head -20
echo
echo "--- database/"
ls -la database/ 2>/dev/null | head -20
echo
echo "--- kok HTML/JS"
wc -l *.html *.js 2>/dev/null | sort -rn | head -15

echo
echo "############ 2. API UC HARITASI ############"
grep -oE "url\.pathname === '[^']+'" server_container.mjs | sed "s/url.pathname === //" | tr -d "'" | sort -u
echo
echo "--- startsWith ile eslesen (parametreli) uclar"
grep -oE "url\.pathname\.startsWith\('[^']+'\)" server_container.mjs | sed "s/url.pathname.startsWith(//" | tr -d "')" | sort -u
echo
echo "--- toplam route sayisi"
grep -cE "url\.pathname === |url\.pathname\.startsWith\(" server_container.mjs

echo
echo "############ 3. UCLAR HANGI GRUPTA ############"
grep -oE "'/api/[a-z_]+/" server_container.mjs | tr -d "'" | sort | uniq -c | sort -rn
