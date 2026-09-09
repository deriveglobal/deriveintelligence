#!/usr/bin/env bash
# TZ_ISTANBUL_V1 — saha shell'lerinde TUM tr-TR/en-CA tarih gosterimlerini Europe/Istanbul'a
#   sabitle. ABD'den (veya baska TZ'den) bakan kullanicida tarihlerin 1 gun geri kaymasini onler.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_tz_istanbul.sh patch_tz_istanbul.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_tz_istanbul.sh'
set -euo pipefail
cd /opt/krb-assessment
[ -f shells/saha_desktop.js ] && [ -f shells/saha.js ] || { echo "HATA: shell yok"; exit 1; }
[ -f patch_tz_istanbul.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

patchla () {  # $1=dosya
  if grep -q 'TZ_ISTANBUL_V1' "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"
  python3 patch_tz_istanbul.py "$1"
  node --check "$1" && echo "[ok] node --check $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }
}
patchla shells/saha_desktop.js
patchla shells/saha.js

docker build -t krb-assessment:secure . >/tmp/tzistanbul_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/tzistanbul_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] desktop marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c TZ_ISTANBUL_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] saha marker: ";    docker exec "$(docker compose ps -q krb-assessment)" grep -c TZ_ISTANBUL_V1 /app/shells/saha.js || true
echo -n "[dogrula] kalan TZ'siz tr-TR (0 bekleniyor): "; docker exec "$(docker compose ps -q krb-assessment)" sh -c 'grep -oh "toLocaleDateString(\"tr-TR\")" /app/shells/saha_desktop.js /app/shells/saha.js | wc -l' || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Masaustu/mobil hard-refresh -> ziyaret tarihleri artik 28.07 (Turkiye gunu) gorunmeli."
