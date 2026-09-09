#!/usr/bin/env bash
# FAZC_TOGGLE (Faz C-frontend) — saha.js donem seciciyi baglar. Onkosul: FAZB_KOKPIT (saha.js) + UMBRELLA_YOY (server).
#   Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_saha_kokpit_fazc.py deploy_saha_kokpit_fazc.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_saha_kokpit_fazc.sh'
set -euo pipefail
cd /opt/krb-assessment
pickjs(){ for p in "shells/$1" "./$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SJ=$(pickjs saha.js) || { echo "HATA: saha.js yok"; exit 1; }
[ -f patch_saha_kokpit_fazc.py ] || { echo "HATA: patch_saha_kokpit_fazc.py yok (scp?)"; exit 1; }
grep -q "FAZB_KOKPIT" "$SJ" || { echo "HATA: once FAZB (saha.js) canli olmali"; exit 1; }
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SV=$(pick server_container.mjs) || true
[ -n "${SV:-}" ] && grep -q "UMBRELLA_YOY" "$SV" || { echo "HATA: once UMBRELLA_YOY (server) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$SJ" "$SJ.bak.$TS"; echo "[yedek] $SJ.bak.$TS"
python3 patch_saha_kokpit_fazc.py "$SJ"
node --check "$SJ" && echo "[ok] node --check (saha.js)" || { echo "HATA: node --check — geri aliniyor"; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/fazc_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/fazc_build.log; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] Faz C-frontend canli. Mobil app Kokpit odasini yeniden ac:"
echo "  - En ustte DONEM cipleri: Bu ay | Son ay | Son 3 ay | YTD"
echo "  - Cipe dokun -> Ciro + Sirket marj + Iki-Is o doneme + YoY (gecen yila) gore degisir."
echo "  - Stok + DSO 'su an' olarak sabit kalir (donem-bagimsiz state metrikleri)."
echo "  - Dikkat karti + alt bolumler AYNEN."
echo "GERI ALMA: cp -a $SJ.bak.$TS $SJ && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
