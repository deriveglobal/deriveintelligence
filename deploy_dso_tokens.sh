#!/usr/bin/env bash
# DSO anlati max_tokens 420 -> 760 (sinifsiz cumlesi kesilmesin). Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_dso_tokens.py deploy_dso_tokens.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_dso_tokens.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_dso_tokens.py ] || { echo "HATA: patch_dso_tokens.py yok (scp?)"; exit 1; }
grep -q "DSO_IKI" "$F" || { echo "HATA: once DSO kokpiti (DSO_IKI) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_dso_tokens.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/dsotok_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/dsotok_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] max_tokens 760. Onemli: eski AI anlatisi cache'te (globalThis.__dsoIc) — recreate cache'i sifirlar,"
echo "  ilk /app acilisinda anlati YENIDEN uretilir ve sinifsiz cumlesi tam biter. Cmd+Shift+R."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
