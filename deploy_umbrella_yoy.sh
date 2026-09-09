#!/usr/bin/env bash
# UMBRELLA_YOY (Faz C-backend) — kokpit-umbrella'ya yoy + canli_gy. ADDITIVE, gorunmez (frontend toggle tuketir).
#   Idempotent + node --check(auto-rollback). Tek basina app'i degistirmez.
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_umbrella_yoy.py deploy_umbrella_yoy.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_umbrella_yoy.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_umbrella_yoy.py ] || { echo "HATA: patch_umbrella_yoy.py yok (scp?)"; exit 1; }
grep -q "kokpit-umbrella" "$F" || { echo "HATA: kokpit-umbrella route yok?"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_umbrella_yoy.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/umbyoy_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/umbyoy_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] Faz C-backend canli. Gorunur degisiklik YOK (foundation)."
echo "  TEST: /api/bi/kokpit-umbrella?ay=1 -> yanitta yeni 'yoy':{ciro,marj,adet} + 'canli_gy':{ciro,adet} olmali."
echo "  Sonraki: Faz C-frontend (donem toggle saha.js) bunu tuketip vitals+Iki-Is'i donem+YoY ile gunceller."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
