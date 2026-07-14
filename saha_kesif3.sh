#!/usr/bin/env bash
# SAHA_KESIF_3 — SON SORU. Eftal'in 403'u HANGI satirdan?
#
# ⚠ Kesif 2 hafizamı bir kez daha curuttu:
#   GET /api/saha/musteriler/{uuid} (28147) icinde SAHIPLIK KONTROLU YOK.
#   Yani "gorsun" ZATEN calisiyor. 403 oradan gelmiyor.
#   Adaylar: 28233 (PUT — burada kalmasi DOGRU) · 29914 ("Bu musteri icin yetkiniz yok")
#   Yanlis yeri yamamaktansa bir tur daha sorarim.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ EFTAL — 13/14 Tem, TUM hatalar, MESAJIYLA ############"
$PSQL -x -c "
SELECT to_char(ts,'DD HH24:MI:SS') AS saat, tip, view_adi, http_status AS kod,
       endpoint, hata_mesaji, extra
  FROM saha_hata_log
 WHERE user_id = 'ae0c55f9-68cc-421d-96d9-409222452f1a'
   AND ts >= current_date - 1
 ORDER BY ts;
"

echo "############ OZET — hangi mesaj kac kez? ############"
$PSQL -c "
SELECT http_status AS kod, coalesce(hata_mesaji,'(bos)') AS mesaj, count(*) AS adet,
       count(DISTINCT endpoint) AS farkli_endpoint
  FROM saha_hata_log
 WHERE ts >= current_date - 1
 GROUP BY 1,2 ORDER BY adet DESC;
"

echo "############ 29914 hangi endpoint'in icinde? ############"
cd /opt/krb-assessment
awk 'NR>=29880 && NR<=29918 { printf "%5d| %s\n", NR, $0 }' server_container.mjs
