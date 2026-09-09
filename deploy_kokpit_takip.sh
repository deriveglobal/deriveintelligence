#!/usr/bin/env bash
# KOKPIT_TAKIP (Izle->Ogren F-1 backend) — takip-baslat + takip-durum. IZOLE, gorunmez (F-2 frontend tuketir).
#   Onkosul: HAFIZA_FULL. Idempotent + node --check(auto-rollback). Tek basina app'i degistirmez.
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_kokpit_takip.py deploy_kokpit_takip.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_kokpit_takip.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_kokpit_takip.py ] || { echo "HATA: patch_kokpit_takip.py yok (scp?)"; exit 1; }
grep -q "HAFIZA_FULL" "$F" || { echo "HATA: once HAFIZA_FULL canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_kokpit_takip.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/takip_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/takip_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] F-1 canli — /api/bi/takip-baslat (POST) + /api/bi/takip-durum (GET). Gorunur degisiklik YOK (foundation)."
echo "  Sonraki: F-2 frontend (aksiyon dux gmesi takibi baslatir + kokpitte 'Takip · sonuclar' bolumu)."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
