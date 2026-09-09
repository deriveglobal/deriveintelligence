#!/usr/bin/env bash
# KRB TUM HATALAR — tek dosyaya dok, Claude'a yapistir. Kullanim (Mac):
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash hata_full.sh 30' > hata_full.txt
#   (30 = son kac gun; hepsi icin buyuk ver: 3650). Sonra hata_full.txt'i ac/yapistir ya da Claude'a yukle.
set -uo pipefail
cd /opt/krb-assessment
T=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
GUN="${1:-30}"; HRS=$((GUN*24))
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off"

echo "############ KRB TUM HATALAR — son ${GUN} gun ############"
echo
echo "==== OZET (tip bazli) ===="
$PSQL -c "SELECT tip, count(*) AS adet FROM saha_hata_log WHERE tenant_id='$T' AND ts > now() - ($GUN * interval '1 day') GROUP BY 1 ORDER BY 2 DESC;"
echo "==== OZET (endpoint/ekran — adet + ortalama/max sure) ===="
$PSQL -c "SELECT COALESCE(NULLIF(endpoint,''), view_adi, '(?)') AS yer, count(*) AS adet, round(avg(duration_ms)) AS ort_ms, max(duration_ms) AS max_ms FROM saha_hata_log WHERE tenant_id='$T' AND ts > now() - ($GUN * interval '1 day') GROUP BY 1 ORDER BY 2 DESC;"
echo
echo "==== TUM HATALAR  (t | tip | kim | ekran | endpoint | kod | ms | mesaj) ===="
$PSQL -A -F ' | ' -c "SELECT to_char(ts,'MM-DD HH24:MI') AS t, tip, COALESCE((SELECT full_name FROM users u WHERE u.id=h.user_id),'-') AS kim, COALESCE(view_adi,'') AS ekran, COALESCE(endpoint,'') AS endpoint, COALESCE(http_status::text,'') AS kod, COALESCE(duration_ms::text,'') AS ms, replace(replace(COALESCE(hata_mesaji,''),chr(10),' '),chr(13),' ') AS mesaj FROM saha_hata_log h WHERE tenant_id='$T' AND ts > now() - ($GUN * interval '1 day') ORDER BY ts DESC LIMIT 5000;"
echo
echo "==== SUNUCU LOG (backend hata satirlari, son ${GUN} gun) ===="
docker logs --since "${HRS}h" krb-assessment 2>&1 | grep -iE "error|unhandled|exception|econnrefused|typeerror|referenceerror|syntaxerror| at /app|rejection|cannot read" | grep -viE "favicon|/health" | tail -200
echo "############ BITTI ############"
