#!/usr/bin/env bash
# YETKI_YARDIM_V1 — uygulama ici "Yardim > Yetki Rehberi" (teknik dokumantasyon). Yalniz tenant-admin.js, salt-oku, DB yok.
#   KULLANIM:
#     scp -i $KEY deploy_yetki_yardim.sh patch_yetki_yardim_client.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_yardim.sh'
set -euo pipefail
cd /opt/krb-assessment
TA=shells/tenant-admin.js
[ -f "$TA" ] && [ -f patch_yetki_yardim_client.py ] || { echo "HATA: dosya yok"; exit 1; }
TS=$(date +%s); cp -a "$TA" "$TA.bak.$TS"; echo "[yedek] $TA.bak.$TS"
python3 patch_yetki_yardim_client.py "$TA" || { cp -a "$TA.bak.$TS" "$TA"; exit 1; }
node --check "$TA" || { echo "HATA node"; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/yardim_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/yardim_build.log; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[ta] YETKI_YARDIM_V1 (4): ";   docker exec "$CID" grep -c YETKI_YARDIM_V1 /app/shells/tenant-admin.js || true
echo -n "[ta] renderYardim (1): ";      docker exec "$CID" grep -c 'function renderYardim' /app/shells/tenant-admin.js || true
echo -n "[ta] nav yardim (1): ";        docker exec "$CID" grep -c 'navBtn(\"yardim\"' /app/shells/tenant-admin.js || true
echo -n "[ta] yh stil (1): ";           docker exec "$CID" grep -c '.yh-hero{' /app/shells/tenant-admin.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_YARDIM_V1',
 'Uygulama ici Yardim > Yetki Rehberi (teknik dokumantasyon, tenant-admin.js, statik salt-oku): 5 ekran + cekirdek model (yetki=(bolum U grant)-deny) + iki eksen (capability/scope) + uc katman (config/client/server) + sik isler (grup yetki/kisiyi kisitla/ekstra ver/neden goruyor/kapsam) + uc listesi + veri modeli (permissions_json + tablolar) + uyarilar. Stiller yh-*.',
 'Fatih: butun yetki ekranlarini/mantigini tek online dokumantasyonda gormek istedi (uygulama ici, teknik).',
 '{"marker":"YETKI_YARDIM_V1","tur":"ux","yuzey":"tenant-admin.js","gorunum":"Yardim>Yetki Rehberi","salt_oku":true}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_YARDIM_V1');
SELECT count(*) yardim FROM bi_insa_gunlugu WHERE adim='YETKI_YARDIM_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_YARDIM_V1 CANLI — Yönetim > Yardım > Yetki Rehberi. (hard-refresh)"
