#!/usr/bin/env bash
# HAFIZA_V2 — davranis madencisi. HAFIZA_V15 CANLI olmali. Idempotent + node --check(auto-rollback).
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_hafiza_v2.py insa_gunlugu_hafiza_v2.sql deploy_hafiza_v2.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_hafiza_v2.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_hafiza_v2.py ] || { echo "HATA: patch_hafiza_v2.py yok (scp?)"; exit 1; }
grep -q "HAFIZA_V15" "$F" || { echo "HATA: once HAFIZA_V15 canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_hafiza_v2.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/hv2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/hv2_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
if [ -f insa_gunlugu_hafiza_v2.sql ]; then
  PG=$(docker ps --format '{{.Names}}' | grep -m1 -i postgres || true)
  [ -n "$PG" ] && cat insa_gunlugu_hafiza_v2.sql | docker exec -i "$PG" psql -U assessment_app -d assessment_platform && echo "[ok] insa gunlugu ($PG)" || echo "[uyari] postgres yok — SQL elle"
fi
echo ""
echo "[bitti] HAFIZA_V2 canli. Madenci ilk CEO chat'inde (ya da davranis_yenile ile) calisir; gunde ~1 kez otomatik."
echo "  TETIKLE: CEO asistanina 'davranislari guncelle' de (davranis_yenile) — kac gozlem yazildigini soyler."
echo "  GOR: docker exec -i \$PG psql -U assessment_app -d assessment_platform -c \"SELECT kategori,konu,left(icerik,64) FROM bi_tenant_hafiza WHERE kaynak='gozlem' AND gecerli ORDER BY son_gorulme DESC LIMIT 20;\""
echo "  SOR: 'kim yavas oduyor / alimi dusen musteri var mi' — asistan gozlemden cevaplamali, sayiyi canli cekmeli."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
