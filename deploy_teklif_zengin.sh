#!/usr/bin/env bash
# SON10_ALIS_V1 + UI — teklif panelini zenginlestir:
#   server: son_alanlar (son 10 alan musteri) + kendi_alis (bu yil alis min/medyan/max) verisi
#   saha  : son 10 musteri KATLANABILIR (goster->modal) + alis min/med/max satiri + en ucuz/pahali TARIH
#   Mobil panel. Rep tarafi degismez. Mevcut alanlar korunur.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_teklif_zengin.sh patch_teklif_zengin_server.py patch_teklif_zengin_saha.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_zengin.sh'
set -euo pipefail
cd /opt/krb-assessment
[ -f server_container.mjs ] && [ -f shells/saha.js ] || { echo "HATA: hedef dosyalar yok"; exit 1; }
[ -f patch_teklif_zengin_server.py ] && [ -f patch_teklif_zengin_saha.py ] || { echo "HATA: patch(ler) yok (scp?)"; exit 1; }
grep -q "console.error('\[teklif_v2\] analiz:'" server_container.mjs || { echo "HATA: teklif_v2 capasi yok — DUR."; exit 1; }
grep -q 'function _aykiriGoster' shells/saha.js || { echo "HATA: _aykiriGoster yok — DUR."; exit 1; }

patchla () {  # $1=patch $2=dosya $3=marker
  if grep -q "$3" "$2"; then echo "[bilgi] $2 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$2" "$2.bak.$TS"; echo "[yedek] $2.bak.$TS"
  python3 "$1" "$2"
  node --check "$2" && echo "[ok] node --check $2" || { echo "HATA node $2; geri al"; cp -a "$2.bak.$TS" "$2"; exit 1; }
}
patchla patch_teklif_zengin_server.py server_container.mjs SON10_ALIS_V1
patchla patch_teklif_zengin_saha.py   shells/saha.js       SON10_ALIS_UI_V1

docker build -t krb-assessment:secure . >/tmp/zengin_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/zengin_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] server SON10_ALIS_V1: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c SON10_ALIS_V1 /app/server.mjs || true
echo -n "[dogrula] saha SON10_ALIS_UI_V1: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c SON10_ALIS_UI_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Mobil -> teklif ac: 'Son alan N müşteri · göster' (modal) + '📥 kaça aldık min-med-max' + en ucuz/pahali yaninda tarih."
