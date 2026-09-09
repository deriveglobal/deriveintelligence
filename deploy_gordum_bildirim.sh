#!/usr/bin/env bash
# ZIYARET_GORDUM_BILDIRIM_V1 — ziyaret detayi acilinca o ziyaretin okunmamis bildirimi
#   (bi_bildirim tip='ziyaret') okundu isaretlensin. Zil/bildirimde "okunmamis ziyaret" temizlenir.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_gordum_bildirim.sh patch_gordum_bildirim.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_gordum_bildirim.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_gordum_bildirim.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
if grep -q 'ZIYARET_GORDUM_BILDIRIM_V1' "$SRV"; then
  echo "[bilgi] $SRV zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_gordum_bildirim.py "$SRV"
  node --check "$SRV" && echo "[ok] node --check" || { echo "HATA node --check; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/gordumbldrm_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/gordumbldrm_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c ZIYARET_GORDUM_BILDIRIM_V1 /app/server.mjs || true
echo "[dogrula] su an okunmamis ziyaret bildirimi sayisi:"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT count(*) AS okunmamis_ziyaret_bildirimi FROM bi_bildirim WHERE tip='ziyaret' AND okundu=false;" || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Bir ziyareti acinca o ziyaretin bildirimi artik okundu olur; tekrar acinca sayac dusmeli."
