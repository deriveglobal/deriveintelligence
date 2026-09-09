#!/usr/bin/env bash
# EKIP_YONETIM_V3 — Yönetim (Tenant Admin) konsolu tam redesign + birleşik İzinler matrisi.
#   Tam DOSYA değişimi (patch değil): shells/tenant-admin.js yenilenir.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY shells/tenant-admin.js $H:/opt/krb-assessment/tenant-admin.new.js
#   scp -i $KEY deploy_ekip_yonetim.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ekip_yonetim.sh'
set -euo pipefail
cd /opt/krb-assessment
NEW=tenant-admin.new.js
DST=shells/tenant-admin.js
[ -f "$NEW" ] || { echo "HATA: $NEW yok — önce scp ile yükleyin"; exit 1; }

# 1) Yeni dosya sözdizimi
node --check "$NEW" || { echo "HATA: node --check (yeni dosya) başarısız"; exit 1; }
grep -q "EKIP_YONETIM_V3" "$NEW" || { echo "HATA: yeni dosyada EKIP_YONETIM_V3 marker yok"; exit 1; }

# 2) Yedek + yerine koy
TS=$(date +%s)
if [ -f "$DST" ]; then cp -a "$DST" "$DST.bak.$TS"; echo "[yedek] $DST.bak.$TS"; fi
cp -a "$NEW" "$DST"
node --check "$DST" || { echo "HATA: node --check ($DST) — geri alınıyor"; [ -f "$DST.bak.$TS" ] && cp -a "$DST.bak.$TS" "$DST"; exit 1; }
echo "[ok] $DST güncellendi"

# 3) Build + recreate
docker build -t krb-assessment:secure . >/tmp/ekipyon_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ekipyon_build.log; [ -f "$DST.bak.$TS" ] && cp -a "$DST.bak.$TS" "$DST"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] konteyner marker: "; docker exec "$CID" grep -c EKIP_YONETIM_V3 /app/shells/tenant-admin.js || true
rm -f "$NEW"
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Yönetim konsolu v3 canlı — 👤 Yönetim > (Genel Bakış · Ekip · İzinler · Davet Et)."
