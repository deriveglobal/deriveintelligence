#!/usr/bin/env bash
# FAZF_TAKIP (Izle->Ogren F-2 frontend) — aksiyon takibi + kokpitte Takip bolumu.
#   Onkosul: FAZE_AKSIYON (saha.js) + KOKPIT_TAKIP (server). Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_saha_kokpit_fazf.py deploy_saha_kokpit_fazf.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_saha_kokpit_fazf.sh'
set -euo pipefail
cd /opt/krb-assessment
pickjs(){ for p in "shells/$1" "./$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SJ=$(pickjs saha.js) || { echo "HATA: saha.js yok"; exit 1; }
[ -f patch_saha_kokpit_fazf.py ] || { echo "HATA: patch_saha_kokpit_fazf.py yok (scp?)"; exit 1; }
grep -q "FAZE_AKSIYON" "$SJ" || { echo "HATA: once FAZE_AKSIYON canli olmali"; exit 1; }
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
SV=$(pick server_container.mjs) || true
[ -n "${SV:-}" ] && grep -q "KOKPIT_TAKIP" "$SV" || { echo "HATA: once KOKPIT_TAKIP (server, F-1) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$SJ" "$SJ.bak.$TS"; echo "[yedek] $SJ.bak.$TS"
python3 patch_saha_kokpit_fazf.py "$SJ"
node --check "$SJ" && echo "[ok] node --check (saha.js)" || { echo "HATA: node --check — geri aliniyor"; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/fazf_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/fazf_build.log; cp -a "$SJ.bak.$TS" "$SJ"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] F-2 canli — IZLE->OGREN dongusu KAPANDI. Uygulamayi tam kapat-ac, Kokpit:"
echo "  - Aksiyon dux gmesine basinca: takip acilir (sessiz) + CEO hazir talimatla acilir."
echo "  - Dikkat'in altinda '🔁 Takip · aksiyon sonuclari' bolumu: acti gin takiplerin sonucu (toparladi ✓ / hâlâ dux suyor)."
echo "  - Ilk gun bos/az olabilir; madenci gunluk calisip sonuc olgunlastikca dolar."
echo "GERI ALMA: cp -a $SJ.bak.$TS $SJ && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
