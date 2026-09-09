#!/usr/bin/env bash
# EKIP_PLAN_V2 (mobil) + EKIP_PLAN_DK_V2 (masaustu) — Ekip Planı: gorsel yeniden tasarim + yetki matrisi kaydi.
#   Gorsel: rep tiklanabilir renkli cipler + gune gore gruplu kartlar (Bugün/Yarın/Bu hafta/Gelecek) + "⚠ Tarihi gecmis".
#   Governance: CATALOG'a "ekip-plan" (yetki matrisinde kolon). Client gating zaten _dok("ekip-plan") + manager rolu.
#   SERVER DEGISMEZ. Canlida EKIP_PLAN_V1/_DK_V1 uzerine uygulanir (v2 anchorlari v1 markerlarini bulur).
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_ekip_plan_v2_client.py patch_ekip_plan_v2_desktop.py deploy_ekip_plan_v2.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ekip_plan_v2.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js; D=shells/saha_desktop.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f "$D" ] || { echo "HATA: $D yok"; exit 1; }
[ -f patch_ekip_plan_v2_client.py ]  || { echo "HATA: mobil v2 patch yok (scp?)"; exit 1; }
[ -f patch_ekip_plan_v2_desktop.py ] || { echo "HATA: masaustu v2 patch yok (scp?)"; exit 1; }

# on-kosul: v1 canlida olmali (v2 v1 uzerine uygulanir)
grep -q 'EKIP_PLAN_V1' "$C" || { echo "HATA: mobil'de EKIP_PLAN_V1 yok — once v1 deploy edilmeli"; exit 1; }
grep -q 'EKIP_PLAN_DK_V1' "$D" || { echo "HATA: masaustu'nde EKIP_PLAN_DK_V1 yok — once v1 deploy edilmeli"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; cp -a "$D" "$D.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_ekip_plan_v2_client.py  "$C"
python3 patch_ekip_plan_v2_desktop.py "$D"

geri_al() { cp -a "$C.bak.$TS" "$C"; cp -a "$D.bak.$TS" "$D"; }
node --check "$C" && echo "[ok] node --check mobil" || { echo "HATA mobil syntax"; geri_al; exit 1; }
cp -a "$D" /tmp/_epd2_check.mjs
node --check /tmp/_epd2_check.mjs && echo "[ok] node --check masaustu (.mjs)" || { echo "HATA masaustu syntax"; geri_al; exit 1; }
rm -f /tmp/_epd2_check.mjs

echo -n "[dogrula] mobil v2 marker: ";    grep -c 'EKIP_PLAN_V2' "$C" || true
echo -n "[dogrula] masaustu v2 marker: "; grep -c 'EKIP_PLAN_DK_V2' "$D" || true
echo -n "[dogrula] CATALOG ekip-plan: ";   grep -c '\["ekip-plan","Ekip Planı"\]' "$D" || true

docker build -t krb-assessment:secure . >/tmp/ekipplan2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ekipplan2_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] container mobil v2: ";    docker exec "$CID" grep -c "EKIP_PLAN_V2" /app/shells/saha.js
echo -n "[dogrula] container masaustu v2: "; docker exec "$CID" grep -c "EKIP_PLAN_DK_V2" /app/shells/saha_desktop.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. Yonetici relaunch / hard refresh."
echo "  Ekip Planı: renkli rep cipleri (kisi secilir), gune gore gruplu kartlar + 'Tarihi gecmis' bolumu."
echo "  Yetki matrisi (masaustu Ekip ekrani): 'Ekip Planı' kolonu goruntulenir. Client _dok('ekip-plan') ile gating."
echo "GERI ALMA: cp -a $C.bak.$TS $C && cp -a $D.bak.$TS $D && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
