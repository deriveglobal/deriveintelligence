#!/usr/bin/env bash
# CUTOVER v2 — host'taki GERÇEK bi.js'i YERİNDE yamalar (Mac'ten bi.js scp'lemeye gerek yok).
# /app 'Finans' odasi iframe: /api/bi/kokpit  ->  /api/bi/kokpit-iki. Idempotent, geri-alinabilir (.bak).
# Kullanim (Mac, deriveapp/):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 deploy_cutover_v2.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_cutover_v2.sh'
set -euo pipefail
cd /opt/krb-assessment
TS=$(date +%s); found=0; patched=0
echo "=== bi.js dosyalari + iframe src durumu ==="
for f in ./bi.js shells/bi.js public/bi.js www/bi.js; do
  [ -f "$f" ] || continue
  found=1
  cur=$(grep -o 'src="/api/bi/kokpit[^"]*"' "$f" | head -1 || true)
  echo "  $f : ${cur:-'(iframe src yok)'}"
  if grep -q 'src="/api/bi/kokpit"' "$f"; then
    cp "$f" "$f.bak.$TS"
    sed -i 's#src="/api/bi/kokpit"#src="/api/bi/kokpit-iki"#g' "$f"
    node --check "$f" >/dev/null 2>&1 && echo "    -> yamalandi (kokpit-iki), node --check ok" || { echo "    HATA: node --check, geri aliniyor"; cp "$f.bak.$TS" "$f"; exit 1; }
    patched=1
  elif grep -q 'src="/api/bi/kokpit-iki"' "$f"; then
    echo "    -> zaten kokpit-iki"
  fi
done
[ "$found" = 1 ] || { echo "HATA: hic bi.js bulunamadi (root/shells/public/www)"; exit 1; }
echo "=== docker build + recreate ==="
docker build -t krb-assessment:secure . >/tmp/cutover_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/cutover_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo ""
echo "[bitti] /app 'Finans' odasi artik YENI kokpiti (kokpit-iki) gosteriyor. TARAYICIDA /app'i HARD REFRESH et (Cmd+Shift+R)."
echo "DOGRULAMA: curl -s https://krb.deriveglobal.com/shells/bi.js | grep -o 'src=\"/api/bi/kokpit[^\"]*\"'   # -> kokpit-iki gormeli"
echo "GERI ALMA: her f icin cp \$f.bak.$TS \$f && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
