#!/usr/bin/env bash
# TEKLIF_KARAR_V1 (Faz 2a) — owner onay ekraninda rep fiyati vs sistem onerisi + saglik.
#   server: TEKLIF_ONERI_V2 (marka/ebat cozumu + manager/admin kilit + rep fiyat sagligi)
#   masaustu: teklifDetay'a owner-only "Sistem Önerisi" bloku (rep vs sistem).
#   Mobil AYRI faz. Rep tarafi degismez.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_teklif_karar.sh patch_teklif_oneri2.py patch_teklif_karar_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_karar.sh'
set -euo pipefail
cd /opt/krb-assessment
[ -f server_container.mjs ] && [ -f shells/saha_desktop.js ] || { echo "HATA: hedef dosyalar yok"; exit 1; }
[ -f patch_teklif_oneri2.py ] && [ -f patch_teklif_karar_desktop.py ] || { echo "HATA: patch(ler) yok (scp?)"; exit 1; }
grep -q 'TEKLIF_ONERI_V1' server_container.mjs || { echo "HATA: TEKLIF_ONERI_V1 yok — once faz1 deploy."; exit 1; }
grep -q 'function teklifDetay' shells/saha_desktop.js || { echo "HATA: teklifDetay yok — DUR."; exit 1; }

patchla () {  # $1=patch $2=dosya $3=marker
  if grep -q "$3" "$2"; then echo "[bilgi] $2 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$2" "$2.bak.$TS"; echo "[yedek] $2.bak.$TS"
  python3 "$1" "$2"
  node --check "$2" && echo "[ok] node --check $2" || { echo "HATA node $2; geri al"; cp -a "$2.bak.$TS" "$2"; exit 1; }
}
patchla patch_teklif_oneri2.py        server_container.mjs      TEKLIF_ONERI_V2
patchla patch_teklif_karar_desktop.py shells/saha_desktop.js    TEKLIF_KARAR_V1

docker build -t krb-assessment:secure . >/tmp/teklifkarar_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/teklifkarar_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] server TEKLIF_ONERI_V2: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c TEKLIF_ONERI_V2 /app/server.mjs || true
echo -n "[dogrula] masaustu TEKLIF_KARAR_V1: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c TEKLIF_KARAR_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Masaustu → onay bekleyen bir teklifi ac → kalem tablosu altinda 'Sistem Önerisi' cikar (rep vs sistem + 🔴🟡🟢)."
