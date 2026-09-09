#!/usr/bin/env bash
# CONTEXT_MSG — #3 slice 3a: baglamsal mesaj (migration + endpoint + musteri kart girisi + 🔗 rozet).
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_context_msg.sh patch_context_msg_server.py patch_context_msg_mobile.py patch_context_msg_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_context_msg.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; MOB=shells/saha.js; DSK=shells/saha_desktop.js
for f in "$SRV" "$MOB" "$DSK" patch_context_msg_server.py patch_context_msg_mobile.py patch_context_msg_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done

# 0) MIGRATION — baglam kolonlari (server yeni imaj bunlari SELECT edecek; ONCE calismali)
echo "[migration] saha_konusma_mesaj baglam kolonlari..."
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "ALTER TABLE saha_konusma_mesaj ADD COLUMN IF NOT EXISTS baglam_tip text, ADD COLUMN IF NOT EXISTS baglam_id text, ADD COLUMN IF NOT EXISTS baglam_etiket text;" && echo "  ok"

pat () { if grep -q "$3" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi; TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"; python3 "$2" "$1"; node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }; }
pat "$SRV" patch_context_msg_server.py  CONTEXT_MSG_V1
pat "$MOB" patch_context_msg_mobile.py  CONTEXT_MSG_V1
pat "$DSK" patch_context_msg_desktop.py CONTEXT_MSG_DK_V1

docker build -t krb-assessment:secure . >/tmp/ctxmsg_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ctxmsg_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server CONTEXT_MSG_V1: "; docker exec "$CID" grep -c CONTEXT_MSG_V1 /app/server.mjs || true
echo -n "[dogrula] mobil CONTEXT_MSG_V1: ";  docker exec "$CID" grep -c CONTEXT_MSG_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu CONTEXT_MSG_DK_V1: "; docker exec "$CID" grep -c CONTEXT_MSG_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] baglam kolon: "; docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT count(*) FROM information_schema.columns WHERE table_name='saha_konusma_mesaj' AND column_name LIKE 'baglam%';" || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Musteri kartinda (yonetici) '💬 Mesaj' -> sorumlu rep'e, 🔗 firma etiketli mesaj."
