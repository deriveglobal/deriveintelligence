echo "############ ODALAR FRONTEND'DE NASIL ADLANIYOR ############"
grep -nE "Bugün|Finans|oda|room|sekme|tab" shells/bi.js | grep -iE "bugun|finans|'ana'|oda|room" | head -20
echo
echo "############ /api/bi/ana ve /api/bi/finans — hangi satirlar ############"
grep -nE "url\.pathname === '/api/bi/(ana|finans|account-health)'" server_container.mjs
echo
echo "############ FINANS endpoint tam sinirlari ############"
grep -nE "'/api/bi/finans'|'/api/bi/ana'|'/api/bi/account-health'" server_container.mjs
