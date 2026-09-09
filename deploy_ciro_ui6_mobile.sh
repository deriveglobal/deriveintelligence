#!/usr/bin/env bash
# CIRO_UI6 (mobil) — yönetici Ciro'yu masaüstü ile eşitle: özet + saha kırılımı + ₺/ziyaret karşılaştırması
#   + rep-alanı seçici (Tümü/Ticari/Tüketici), dar ekrana göre yığılmış. Rep görünümü korunur.
#   Server tarafı zaten canlı (CIRO_SEG_SRV_V1). Yalnız shells/saha.js. rpCiro'yu yeniden yazar (CIRO_UI2'nin yerine).
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ciro_ui6_mobile.sh patch_ciro_ui6_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ciro_ui6_mobile.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_ciro_ui6_mobile.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "async function rpCiro" "$MOB" || { echo "HATA: mobil Ciro (rpCiro) yok — once ZIYARET_CIRO_UI_V1/CIRO_UI2_V1"; exit 1; }
if grep -q CIRO_UI6_V1 "$MOB"; then
  echo "[bilgi] $MOB zaten yamali"
else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_ciro_ui6_mobile.py "$MOB"
  node --check "$MOB" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  cp "$MOB" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/c6m_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/c6m_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] CIRO_UI6_V1: "; docker exec "$CID" grep -c CIRO_UI6_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Mobil Ciro (yönetici) masaüstü ile eşit — kırılım + karşılaştırma + seçici. Uygulamayı yeniden aç."
