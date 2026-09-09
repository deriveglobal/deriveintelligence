#!/usr/bin/env bash
# FAZE_AKSIYON — dinamik kokpit: Dikkat sinyallerine aksiyon duxgmeleri (setRoom ceo + prefill).
#   Onkosul: FAZD_OWNERLENS (saha.js). Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_saha_kokpit_faze.py deploy_saha_kokpit_faze.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_saha_kokpit_faze.sh'
set -euo pipefail
cd /opt/krb-assessment
pickjs(){ for p in "shells/$1" "./$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SJ=$(pickjs saha.js) || { echo "HATA: saha.js yok"; exit 1; }
[ -f patch_saha_kokpit_faze.py ] || { echo "HATA: patch_saha_kokpit_faze.py yok (scp?)"; exit 1; }
grep -q "FAZD_OWNERLENS" "$SJ" || { echo "HATA: once FAZD_OWNERLENS canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$SJ" "$SJ.bak.$TS"; echo "[yedek] $SJ.bak.$TS"
python3 patch_saha_kokpit_faze.py "$SJ"
node --check "$SJ" && echo "[ok] node --check (saha.js)" || { echo "HATA: node --check — geri aliniyor"; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/faze_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/faze_build.log; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] Faz E canli — DINAMIK kokpit. Uygulamayi tam kapat-ac, Kokpit odasi:"
echo "  Dikkat kartinda YENI duxgmeler: '→ Ziyaret gorevi ac' · '→ Tahsilat gorevi ac' · '→ Firsat gorevi ac' · '🧠 Asistana danis'"
echo "  Dokun -> CEO Assistant HAZIR talimatla acilir -> sen gonder -> asistan gorevi/hatirlatmayi UYGULAR."
echo "GERI ALMA: cp -a $SJ.bak.$TS $SJ && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
