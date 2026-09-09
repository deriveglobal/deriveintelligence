#!/usr/bin/env bash
# CUTOVER — /app 'Finans' odasi kokpiti: eski /api/bi/kokpit -> yeni /api/bi/kokpit-iki (bi.js iframe src).
# Tek satirlik, GERI ALINABILIR degisiklik. Endpoint dokunulmaz; sadece uygulamanin gosterdigi iframe route'u degisir.
# Kullanim (Mac, deriveapp/):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 bi.js shells/kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/...
#   (bi.js -> /opt/krb-assessment/bi.js ; shell -> /opt/krb-assessment/shells/)
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 bi.js root@5.161.234.59:/opt/krb-assessment/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 shells/kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/shells/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 deploy_cutover.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_cutover.sh'
set -euo pipefail
cd /opt/krb-assessment
[ -f bi.js ] || { echo "HATA: bi.js yok (scp?)"; exit 1; }
grep -q 'src="/api/bi/kokpit-iki"' bi.js || { echo "HATA: bi.js'de yeni iframe src yok — dogru bi.js mi? (scp?)"; exit 1; }
if grep -q 'src="/api/bi/kokpit"' bi.js; then echo "UYARI: bi.js'de hala eski src var (beklenmez)"; fi
TS=$(date +%s); echo "[bilgi] cutover $TS — /app kokpiti -> kokpit-iki"
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo ""
echo "[bitti] /app 'Finans' odasi artik YENI kokpiti (kokpit-iki) gosteriyor."
echo "GERI ALMA: bi.js'de src=\"/api/bi/kokpit-iki\" -> src=\"/api/bi/kokpit\" yap, tekrar scp + bu script."
echo "  (veya onceki bi.js yedegini koy: cp bi.js.bak.$TS bi.js && docker build ... && docker compose up ...)"
