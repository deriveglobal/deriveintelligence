#!/usr/bin/env bash
# HAFIZA_FULL — birlesik hafiza (session-fix). ESKI deploy_hafiza(.v15/.v2).sh KULLANMA; SADECE bu.
#   patch_hafiza.py (tek) canli server_container.mjs'e; node --check auto-rollback; race-safe tablo.
# Kullanim (Mac, deriveapp/):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_hafiza.py insa_gunlugu_hafiza_full.sql deploy_hafiza_fix.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_hafiza_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f patch_hafiza.py ] || { echo "HATA: patch_hafiza.py yok (scp?)"; exit 1; }
grep -q "_handleBrainChat" "$F" || { echo "HATA: ana beyin bulunamadi"; exit 1; }
if grep -q "HAFIZA_V1\|HAFIZA_V15\|HAFIZA_V2" "$F"; then echo "HATA: eski/kismi HAFIZA markerlari var — once V1 oncesi yedege don, sonra bunu uygula."; exit 1; fi
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_hafiza.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/hafiza_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/hafiza_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
if [ -f insa_gunlugu_hafiza_full.sql ]; then
  PG=$(docker ps --format '{{.Names}}' | grep -m1 -i postgres || true)
  [ -n "$PG" ] && cat insa_gunlugu_hafiza_full.sql | docker exec -i "$PG" psql -U assessment_app -d assessment_platform && echo "[ok] insa gunlugu ($PG)" || echo "[uyari] postgres yok — SQL elle"
fi
echo ""
echo "[bitti] HAFIZA_FULL canli. ONCE test: CEO Assistant'i ac, bir mesaj yaz — 500 GELMEMELI (session fix dogrulandi)."
echo "  Damitma her turdan sonra; madenci ilk chatte + gunde 1. Gozlem icin: 'davranislari guncelle' de."
echo "  GOR: docker exec -i \$PG psql -U assessment_app -d assessment_platform -c \"SELECT kategori,kaynak,guven,left(icerik,55) FROM bi_tenant_hafiza WHERE gecerli ORDER BY son_gorulme DESC LIMIT 15;\""
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
