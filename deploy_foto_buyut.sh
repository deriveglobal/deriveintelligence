#!/usr/bin/env bash
# FOTO_BUYUT_V1 — ziyaret fotoğraflarına dokun/tıkla → TAM EKRAN büyüt (lightbox).
#   Mobil (shells/saha.js) + Masaüstü (shells/saha_desktop.js) ziyaret detay foto ızgarası.
#   Fotoğrafa dokun → siyah tam-ekran; arka plana/✕'e dokun → kapat.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_foto_buyut.sh patch_foto_buyut_mobil.py patch_foto_buyut_masaustu.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_foto_buyut.sh'
set -euo pipefail
cd /opt/krb-assessment
for F in shells/saha.js shells/saha_desktop.js; do [ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }; done
[ -f patch_foto_buyut_mobil.py ] && [ -f patch_foto_buyut_masaustu.py ] || { echo "HATA: patch(ler) yok (scp?)"; exit 1; }

patchla () {  # $1=patch $2=dosya
  if grep -q 'FOTO_BUYUT_V1' "$2"; then echo "[bilgi] $2 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$2" "$2.bak.$TS"; echo "[yedek] $2.bak.$TS"
  python3 "$1" "$2"
  node --check "$2" && echo "[ok] node --check $2" || { echo "HATA node $2; geri al"; cp -a "$2.bak.$TS" "$2"; exit 1; }
}
patchla patch_foto_buyut_mobil.py     shells/saha.js
patchla patch_foto_buyut_masaustu.py  shells/saha_desktop.js

docker build -t krb-assessment:secure . >/tmp/fotobuyut_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/fotobuyut_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] mobil marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c FOTO_BUYUT_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c FOTO_BUYUT_V1 /app/shells/saha_desktop.js || true
# DISK HIJYENI — eski imajları temizle (disk dolması bir daha yaşanmasın)
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Cmd+Shift+R / uygulamayı yeniden aç → ziyaret fotoğrafına dokun, büyür."
