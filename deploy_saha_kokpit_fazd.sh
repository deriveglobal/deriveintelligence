#!/usr/bin/env bash
# FAZD_OWNERLENS — mobil Kokpit owner-lens duzen (vKokpitMobil tam degisim). Onkosul: FAZC_TOGGLE (saha.js).
#   Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_saha_kokpit_fazd.py deploy_saha_kokpit_fazd.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_saha_kokpit_fazd.sh'
set -euo pipefail
cd /opt/krb-assessment
pickjs(){ for p in "shells/$1" "./$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SJ=$(pickjs saha.js) || { echo "HATA: saha.js yok"; exit 1; }
[ -f patch_saha_kokpit_fazd.py ] || { echo "HATA: patch_saha_kokpit_fazd.py yok (scp?)"; exit 1; }
grep -q "FAZC_TOGGLE" "$SJ" || { echo "HATA: once FAZC_TOGGLE (saha.js) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$SJ" "$SJ.bak.$TS"; echo "[yedek] $SJ.bak.$TS"
python3 patch_saha_kokpit_fazd.py "$SJ"
node --check "$SJ" && echo "[ok] node --check (saha.js)" || { echo "HATA: node --check — geri aliniyor"; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/fazd_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/fazd_build.log; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] Faz D canli — owner-lens mobil Kokpit. Uygulamayi tam kapat-ac:"
echo "  ① Bugun ne yapmali (Dikkat) → ② Nabiz: Ciro/Marj(donem) + DSO/Gecikmis(kirmizi, su an) + Iki-Is"
echo "  → ③ Nakit: vade + gecikme kaynagi + simulasyon → ④ Kirilim: Marka/Segment/Kanal/Sezon/Stok/Radar/Icgoru (DOKUN-AC)"
echo "  Finansal Icgoru (AI, uydurma ₺) CIKTI; deterministik gecikme+simulasyon Nakit'te KALDI."
echo "GERI ALMA: cp -a $SJ.bak.$TS $SJ && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
