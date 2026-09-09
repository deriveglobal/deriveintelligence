#!/usr/bin/env bash
# HAFIZA_V1 — CEO Assistant kalici hafiza + kisi profili (Faz 1).
#   patch_hafiza_v1.py -> bi_tenant_hafiza + otomatik damitma + alaka bazli hatirlama (ana beyin).
#   insa_gunlugu_hafiza.sql -> platform insa gunlugu (tenant-agnostik mimari).
#   Idempotent + node --check(auto-rollback). Multi-tenant korunur.
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_hafiza_v1.py insa_gunlugu_hafiza.sql deploy_hafiza.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_hafiza.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_hafiza_v1.py ] || { echo "HATA: patch_hafiza_v1.py yok (scp?)"; exit 1; }
grep -q "_handleBrainChat" "$F" || { echo "HATA: ana beyin (_handleBrainChat) bulunamadi — yanlis dosya?"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS ($F)"

python3 patch_hafiza_v1.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/hafiza_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/hafiza_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

if [ -f insa_gunlugu_hafiza.sql ]; then
  PG=$(docker ps --format '{{.Names}}' | grep -m1 -i postgres || true)
  if [ -n "$PG" ]; then
    cat insa_gunlugu_hafiza.sql | docker exec -i "$PG" psql -U assessment_app -d assessment_platform && echo "[ok] insa gunlugu ($PG)" || echo "[uyari] insa gunlugu psql hatasi — sunucu yine canli"
  else echo "[uyari] postgres container yok — insa_gunlugu_hafiza.sql elle calistir"; fi
fi

echo ""
echo "[bitti] HAFIZA_V1 canli. Tablo (bi_tenant_hafiza) ilk chat turunda olusur."
echo "  TEST 1 (damitma): CEO asistanina kalici bir sey soyle — or 'ben once hep nakit/tahsilat durumuna bakarim, rakami net ver'."
echo "  TEST 2 (birkac tur sonra): docker exec -i \$PG psql -U assessment_app -d assessment_platform -c \"SELECT kategori,konu,left(icerik,60),kisi FROM bi_tenant_hafiza ORDER BY son_gorulme DESC LIMIT 10;\""
echo "  TEST 3 (hatirlama): ilgili konuyu tekrar ac — asistan profili/gecmis gercegi hatirlamali (ama sayilari canli cekmeli)."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
