echo "############ 1. ZIYARET KAYDET — POST /api/saha/ziyaretler ############"
grep -n 'path === "/api/saha/ziyaretler"' server_container.mjs
echo "--- POST bloku (ilk 55 satir):"
awk '/method === "POST" && path === "\/api\/saha\/ziyaretler"/{f=1} f{print NR": "$0; if(++n>55)exit}' server_container.mjs

echo
echo "############ 2. _applyIntents — sinyal kaydeden fonksiyon ############"
grep -n "function _applyIntents\|function _extractIntent" server_container.mjs
