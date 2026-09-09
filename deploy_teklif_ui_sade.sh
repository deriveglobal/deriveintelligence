#!/usr/bin/env bash
# TEKLIF_UI_SADE_V1 — Teklif sekmesi metin temizliği (FULL_CONTROL sonrası):
#   • Eşik kutusu "≤%2 oto · … GM" → "Tüm teklifler yönetici onayına gider"
#   • Kart + detaydaki "Müdür/GM onayı gerekli" → "Yönetici onayı gerekli"
#   (İskonto eşik editörü butonu KALIR — ayrı iskonto-talep akışını yönetir.)
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_teklif_ui_sade.sh patch_teklif_ui_sade.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_ui_sade.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_teklif_ui_sade.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'Genel eşik' "$F" || { echo "HATA: $F eşik kutusu yok — DUR."; exit 1; }
if grep -q 'TEKLIF_UI_SADE_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_teklif_ui_sade.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/uisade_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/uisade_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/shells/saha.js (TEKLIF_UI_SADE_V1, 1 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c TEKLIF_UI_SADE_V1 /app/shells/saha.js || true
echo "[BITTI] Cmd+Shift+R / uygulamayı yeniden aç. Teklif sekmesindeki eşik metni sadeleşti."
