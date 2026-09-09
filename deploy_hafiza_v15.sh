#!/usr/bin/env bash
# HAFIZA_V15 — beyan/gozlem + unut. HAFIZA_V1 CANLI olmali. Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_hafiza_v15.py insa_gunlugu_hafiza_v15.sql deploy_hafiza_v15.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_hafiza_v15.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_hafiza_v15.py ] || { echo "HATA: patch_hafiza_v15.py yok (scp?)"; exit 1; }
grep -q "HAFIZA_V1" "$F" || { echo "HATA: once HAFIZA_V1 canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_hafiza_v15.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/hv15_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/hv15_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
if [ -f insa_gunlugu_hafiza_v15.sql ]; then
  PG=$(docker ps --format '{{.Names}}' | grep -m1 -i postgres || true)
  [ -n "$PG" ] && cat insa_gunlugu_hafiza_v15.sql | docker exec -i "$PG" psql -U assessment_app -d assessment_platform && echo "[ok] insa gunlugu ($PG)" || echo "[uyari] postgres yok — SQL elle"
fi
echo ""
echo "[bitti] HAFIZA_V15 canli. Damitma artik kaynak (beyan/gozlem) + guven etiketler; hatirlama gozlemi one alir."
echo "  TEST unut: CEO asistanina bir sey ogret, sonra 'onu unut / yanlis tanidin' de -> unut_hafiza cagirmali."
echo "  TEST etiket: bi_tenant_hafiza'da kaynak/guven kolonlarina bak (SELECT kategori,kaynak,guven,left(icerik,50) FROM bi_tenant_hafiza ORDER BY son_gorulme DESC LIMIT 10;)."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
