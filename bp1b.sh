echo "=== PARAMETRELI UCLAR (startsWith) ==="
grep -oE "url\.pathname\.startsWith\('[^']+'\)" server_container.mjs | sed "s/url.pathname.startsWith(//" | tr -d "')" | sort -u
echo
echo "=== TOPLAM ROUTE SAYISI ==="
grep -cE "url\.pathname === |url\.pathname\.startsWith\(" server_container.mjs
echo
echo "=== UC GRUPLARI (kac tane hangi ailede) ==="
grep -oE "'/api/[a-z-]+/" server_container.mjs | tr -d "'" | sort | uniq -c | sort -rn
echo
echo "=== SAHA UCLARI (yukarida kesilmisti) ==="
grep -oE "'/api/saha[^']*'" server_container.mjs | tr -d "'" | sort -u | head -40
