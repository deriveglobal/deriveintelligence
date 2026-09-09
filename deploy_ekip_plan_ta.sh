#!/usr/bin/env bash
# EKIP_PLAN_TA_V1 (tenant-admin.js) — "ekip-plan" capability'sini grant editorune kaydet (governance kapanisi).
#   MODULES.saha "Yönetim & Analiz" grubuna + manager DEFAULTS'a eklenir → Bölümler/Kişiler editorunde checkbox, yonetici varsayilan.
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_ekip_plan_ta.py deploy_ekip_plan_ta.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ekip_plan_ta.sh'
set -euo pipefail
cd /opt/krb-assessment
T=shells/tenant-admin.js
[ -f "$T" ] || { echo "HATA: $T yok"; exit 1; }
[ -f patch_ekip_plan_ta.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$T" "$T.bak.$TS"; echo "[yedek] $T.bak.$TS"

python3 patch_ekip_plan_ta.py "$T"

geri_al() { cp -a "$T.bak.$TS" "$T"; }
# ES-modul → .mjs kopyada check
cp -a "$T" /tmp/_ta_check.mjs
node --check /tmp/_ta_check.mjs && echo "[ok] node --check (.mjs)" || { echo "HATA syntax"; geri_al; exit 1; }
rm -f /tmp/_ta_check.mjs

echo -n "[dogrula] ekip-plan (2 beklenir): "; grep -c 'ekip-plan' "$T" || true

docker build -t krb-assessment:secure . >/tmp/ekipplanta_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ekipplanta_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] container ekip-plan: "; docker exec "$CID" grep -c "ekip-plan" /app/shells/tenant-admin.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. Yönetim konsolu relaunch/hard refresh."
echo "  Bölümler + Kişiler editorunde 'Yönetim & Analiz' altinda 'Ekip Planı' checkbox'i cikar (ata/kaldir)."
echo "  Yonetici varsayilan alir; rep almaz; admin otomatik."
echo "GERI ALMA: cp -a $T.bak.$TS $T && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
