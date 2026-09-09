#!/usr/bin/env bash
# KRB HATA TOPLAYICI — ciktisini kopyalayip Claude'a yapistir. Kullanim:
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash hata_raporu.sh 2'   (2 = son kac gun, varsayilan 2)
set -uo pipefail
cd /opt/krb-assessment
T=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
GUN="${1:-2}"; HRS=$((GUN*24))
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off"

echo "############ KRB HATA RAPORU — son ${GUN} gun ############"
echo
echo "==== 1) HATA OZETI (tip bazli) ===="
$PSQL -c "SELECT tip, count(*) AS adet FROM saha_hata_log WHERE tenant_id='$T' AND ts > now() - ($GUN * interval '1 day') GROUP BY 1 ORDER BY 2 DESC;"

echo "==== 2) EN COK HATA VEREN EKRAN/ENDPOINT ===="
$PSQL -c "SELECT COALESCE(NULLIF(endpoint,''), view_adi, '(?)') AS yer, count(*) AS adet FROM saha_hata_log WHERE tenant_id='$T' AND ts > now() - ($GUN * interval '1 day') GROUP BY 1 ORDER BY 2 DESC LIMIT 15;"

echo "==== 3) SON HATALAR (en yeni 80) ===="
$PSQL -c "SELECT to_char(ts,'MM-DD HH24:MI') AS t, tip, COALESCE((SELECT full_name FROM users u WHERE u.id=h.user_id),'-') AS kim, COALESCE(view_adi,'') AS ekran, COALESCE(endpoint,'') AS endpoint, COALESCE(http_status::text,'') AS kod, left(COALESCE(hata_mesaji,''),160) AS mesaj FROM saha_hata_log h WHERE tenant_id='$T' AND ts > now() - ($GUN * interval '1 day') ORDER BY ts DESC LIMIT 80;"

echo "==== 4) SUNUCU LOG (backend hata satirlari, son ${GUN} gun) ===="
docker logs --since "${HRS}h" krb-assessment 2>&1 \
  | grep -iE "error|unhandled|exception|econnrefused|typeerror|referenceerror|syntaxerror| at /app|rejection|cannot read" \
  | grep -viE "favicon|/health" | tail -60

echo "############ BITTI — yukaridaki her seyi kopyalayip Claude'a yapistir ############"
