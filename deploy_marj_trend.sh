#!/usr/bin/env bash
# MARJ TRENDİ — endpoint (marj_trend, son 13 ay tuk/tic) + shell sparkline (01 Şirket altı).
#   6-ay marj inişi + canlı Temmuz toparlaması tek grafikte. Idempotent, node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_marj_trend.py deploy_marj_trend.sh root@5.161.234.59:/opt/krb-assessment/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 shells/kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/shells/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_marj_trend.sh'
set -euo pipefail
cd /opt/krb-assessment
# gercek servis edilen server: once ./ sonra shells/
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f shells/kokpit_iki.html ] || { echo "HATA: shells/kokpit_iki.html yok (scp?)"; exit 1; }
[ -f patch_marj_trend.py ] || { echo "HATA: patch_marj_trend.py yok (scp?)"; exit 1; }
grep -q "MARJ_RAW_FIX" "$F" || { echo "HATA: once kokpit-umbrella (Stage 1) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS ($F)"
python3 patch_marj_trend.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/mt_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/mt_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] Marj trendi canli. /app hard-refresh (Cmd+Shift+R) -> 01 Sirket altinda sparkline."
echo "  Test: fetch('/api/bi/kokpit-umbrella?ay=1').then(r=>r.json()).then(d=>console.log('marj_trend:',d.marj_trend.length,'ay'))"
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
