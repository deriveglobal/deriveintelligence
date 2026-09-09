#!/usr/bin/env bash
# MOBIL_DIKKAT (Faz A) — izole /api/bi/mobil-dikkat endpoint'i. HAFIZA_FULL onkosul (bi_tenant_hafiza).
#   Yeni route; mevcut hicbir seye dokunmaz. Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_mobil_dikkat.py deploy_mobil_dikkat.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_mobil_dikkat.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_mobil_dikkat.py ] || { echo "HATA: patch_mobil_dikkat.py yok (scp?)"; exit 1; }
grep -q "HAFIZA_FULL" "$F" || { echo "HATA: once HAFIZA_FULL canli olmali (bi_tenant_hafiza)"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_mobil_dikkat.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/mdikkat_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/mdikkat_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] Faz A canli — /api/bi/mobil-dikkat. Mevcut kokpit AYNEN calisiyor (yeni route sadece)."
echo "  TEST (sunucudan, oturum cookie'siyle): curl -s localhost/api/bi/mobil-dikkat -H 'cookie: ...' "
echo "  Beklenen JSON: { kayip:[...], buyuyen:[...], yavas:[...], gecikme:{ad,net_m,ilk5_pct} }"
echo "  Not: kayip/buyuyen bi_tenant_hafiza gozleminden gelir — madenci en az bir kez calismis olmali (davranislari guncelle)."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
