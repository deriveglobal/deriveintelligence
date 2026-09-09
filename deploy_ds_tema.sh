#!/usr/bin/env bash
# DS_TEMA — GLOBAL tasarım temeli adım 1: koyu-tema sızıntı önleyici (.dk-app düzeyi).
#   TÜM masaüstü saha görünümleri (mevcut + gelecek) açık/okunur kalır. Kapsam dahil hepsini düzeltir.
#   (Sekmeye özel KAPSAM_DK_TEMA'ya gerek kalmaz; varsa da zararsız.) Masaüstü. Tek build.
# KULLANIM: cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ds_tema.sh patch_ds_tema_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ds_tema.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_ds_tema_desktop.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q '.dk-app \*{box-sizing:border-box}' "$DSK" || { echo "HATA: .dk-app tabani yok"; exit 1; }
if grep -q DS_TEMA_V1 "$DSK"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_ds_tema_desktop.py "$DSK" || { echo "PATCH HATASI; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
  node --check "$DSK" || { echo "HATA node; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
  cp "$DSK" /tmp/_c.mjs; node --check /tmp/_c.mjs || { echo "HATA esm; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/dstema_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/dstema_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] DS_TEMA: "; docker exec "$CID" grep -c DS_TEMA_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Tüm masaüstü saha görünümleri koyu-sızıntıya karşı bağışık. Hard-refresh + tüm sekmeleri gez."
