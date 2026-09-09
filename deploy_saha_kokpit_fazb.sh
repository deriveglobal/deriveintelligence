#!/usr/bin/env bash
# FAZB_KOKPIT (Faz B) — saha.js mobil Kokpit ust katman (Dikkat + Iki-Is + YoY). ADDITIVE.
#   Onkosul: MOBIL_DIKKAT endpoint canli (Faz A). Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_saha_kokpit_fazb.py deploy_saha_kokpit_fazb.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_saha_kokpit_fazb.sh'
set -euo pipefail
cd /opt/krb-assessment
# saha.js: once shells/ sonra ./
pickjs(){ for p in "shells/$1" "./$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SJ=$(pickjs saha.js) || { echo "HATA: saha.js yok"; exit 1; }
[ -f patch_saha_kokpit_fazb.py ] || { echo "HATA: patch_saha_kokpit_fazb.py yok (scp?)"; exit 1; }
# onkosul: mobil-dikkat endpoint sunucuda olmali
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SV=$(pick server_container.mjs) || true
[ -n "${SV:-}" ] && grep -q "MOBIL_DIKKAT" "$SV" || { echo "HATA: once MOBIL_DIKKAT (Faz A) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$SJ" "$SJ.bak.$TS"; echo "[yedek] $SJ.bak.$TS"
python3 patch_saha_kokpit_fazb.py "$SJ"
node --check "$SJ" && echo "[ok] node --check (saha.js)" || { echo "HATA: node --check — geri aliniyor"; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/fazb_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/fazb_build.log; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] Faz B canli. Mobil app'te Kokpit odasini ac (hard-refresh/uygulamayi yeniden ac):"
echo "  - Vitals'in altinda YENI: '⚡ Bugun ne yapmali' karti (kayip/gecikme/buyuyen) + '⑂ Iki Is' catali."
echo "  - Vitals etiketi artik 'YoY · gy ...' (gecen yila gore)."
echo "  - Mevcut bolumler (kanal/segment/marka/vade/gecikme/radar) AYNEN altinda."
echo "  Dikkat karti bossa: CEO Assistant'a 'davranislari guncelle' de (madenci gozlemi doldurur)."
echo "GERI ALMA: cp -a $SJ.bak.$TS $SJ && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
