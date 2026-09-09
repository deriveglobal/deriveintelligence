#!/usr/bin/env bash
# EKIP_PLAN_V1 (mobil saha.js) + EKIP_PLAN_DK_V1 (masaustu saha_desktop.js) — Yonetici ziyaret plani gorunumu.
#   PASIF: Plan sekmesi yoneticide KENDI planlari + yeni "Ekip Planı" (tum ekip, rep filtreli) + mobilde rep detayinda plan.
#   SERVER DEGISMEZ (/api/saha/ziyaretler zaten yoneticiye rep-filtresiz + ?rep_id ile doner). Client-only.
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_ekip_plan_client.py patch_ekip_plan_desktop.py deploy_ekip_plan.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ekip_plan.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js; D=shells/saha_desktop.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f "$D" ] || { echo "HATA: $D yok"; exit 1; }
[ -f patch_ekip_plan_client.py ]  || { echo "HATA: mobil patch yok (scp?)"; exit 1; }
[ -f patch_ekip_plan_desktop.py ] || { echo "HATA: masaustu patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; cp -a "$D" "$D.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_ekip_plan_client.py  "$C"
python3 patch_ekip_plan_desktop.py "$D"

geri_al() { cp -a "$C.bak.$TS" "$C"; cp -a "$D.bak.$TS" "$D"; }
# mobil saha.js duz JS → dogrudan check
node --check "$C" && echo "[ok] node --check mobil" || { echo "HATA mobil syntax"; geri_al; exit 1; }
# masaustu saha_desktop.js ES-modul → .mjs kopyada check
cp -a "$D" /tmp/_epd_check.mjs
node --check /tmp/_epd_check.mjs && echo "[ok] node --check masaustu (.mjs)" || { echo "HATA masaustu syntax"; geri_al; exit 1; }
rm -f /tmp/_epd_check.mjs

echo -n "[dogrula] mobil marker: ";    grep -c 'EKIP_PLAN_V1' "$C" || true
echo -n "[dogrula] masaustu marker: "; grep -c 'EKIP_PLAN_DK_V1' "$D" || true

docker build -t krb-assessment:secure . >/tmp/ekipplan_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ekipplan_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] container mobil marker: ";    docker exec "$CID" grep -c "EKIP_PLAN_V1" /app/shells/saha.js
echo -n "[dogrula] container masaustu marker: "; docker exec "$CID" grep -c "EKIP_PLAN_DK_V1" /app/shells/saha_desktop.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. Yonetici relaunch / hard refresh."
echo "  Mobil: Daha → 'Ekip Planı' (yonetici). Plan sekmesi artik yoneticinin KENDI plani. Temsilci detayinda 'Gelecek planı'."
echo "  Masaustu: sol nav 'Yönetim Analiz' → 'Ekip Planı'. Plan gorunumu yoneticide KENDI plani."
echo "GERI ALMA: cp -a $C.bak.$TS $C && cp -a $D.bak.$TS $D && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
