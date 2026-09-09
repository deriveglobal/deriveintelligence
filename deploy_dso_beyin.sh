#!/usr/bin/env bash
# DSO KOKPİTİ + CEO ASİSTANI BEYNİ — tek deploy.
#   1) patch_dso.py         -> /api/bi/dso-icgoru (işe-bazında DSO sayıları + AI anlatı)
#   2) patch_beyin_iki_is.py-> CEO Asistanı sistem haritasına İki-İş/marj-trend/DSO katmanı (tenant-agnostik kural)
#   3) shells/kokpit_iki.html -> Nakit bölümünde DSO teşhis kartı
#   4) insa_gunlugu_iki_is.sql -> platform inşa günlüğü (bi_insa_gunlugu, tenant-agnostik; SAYI YOK)
#   Idempotent + node --check(auto-rollback). Multi-tenant korunur: KRB tek tenant, sayılar CANLI.
# Kullanim (Mac, deriveapp/ klasoru):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_dso.py patch_beyin_iki_is.py insa_gunlugu_iki_is.sql deploy_dso_beyin.sh $H:/opt/krb-assessment/
#   scp -i $KEY shells/kokpit_iki.html $H:/opt/krb-assessment/shells/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_dso_beyin.sh'
set -euo pipefail
cd /opt/krb-assessment

# gercek servis edilen server: once ./ sonra shells/
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }
F=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
[ -f shells/kokpit_iki.html ] || { echo "HATA: shells/kokpit_iki.html yok (scp?)"; exit 1; }
[ -f patch_dso.py ]          || { echo "HATA: patch_dso.py yok (scp?)"; exit 1; }
[ -f patch_beyin_iki_is.py ] || { echo "HATA: patch_beyin_iki_is.py yok (scp?)"; exit 1; }
# onkosul: kokpit-umbrella + marj-trend + musteri-evreni canli olmali (DSO onlarin uzerine biner)
grep -q "MUSTERI_EVRENI_V1" "$F" || { echo "HATA: once musteri-evreni (onceki stage) canli olmali"; exit 1; }

TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS ($F)"

# --- 1+2) sunucu patchleri (idempotent) ---
python3 patch_dso.py "$F"
python3 patch_beyin_iki_is.py "$F"

# --- node --check (auto-rollback) ---
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }

# --- 3) build + recreate ---
docker build -t krb-assessment:secure . >/tmp/dso_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/dso_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

# --- 4) insa gunlugu (bi_insa_gunlugu, idempotent WHERE NOT EXISTS) ---
if [ -f insa_gunlugu_iki_is.sql ]; then
  PG=$(docker ps --format '{{.Names}}' | grep -m1 -i postgres || true)
  if [ -n "$PG" ]; then
    cat insa_gunlugu_iki_is.sql | docker exec -i "$PG" psql -U assessment_app -d assessment_platform && echo "[ok] insa gunlugu eklendi ($PG)" || echo "[uyari] insa gunlugu psql hatasi — sunucu yine de canli, SQL'i elle calistir"
  else
    echo "[uyari] postgres container bulunamadi — insa_gunlugu_iki_is.sql'i elle calistir"
  fi
fi

echo ""
echo "[bitti] DSO kokpiti + CEO asistani beyni canli. /app hard-refresh (Cmd+Shift+R) -> Nakit bolumunde DSO teshis karti."
echo "  Test API : curl -s localhost/api/bi/dso-icgoru -H 'cookie: ...' | head"
echo "  Test beyin: CEO asistanina sor -> 'tuketici mi ticari mi daha temiz odiyor?' / 'marjim neden dustu?'"
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
