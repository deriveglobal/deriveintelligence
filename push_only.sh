#!/usr/bin/env bash
# push_only.sh — SADECE gercek push gonderir (mesaj/zil tekrar EKLEMEZ).
#   Onceki EACCES: container'da node root-olmayan kullanici; /tmp'deki root dosyayi
#   okuyamadi. Cozum: dosyalari 0644 yap + node'u root olarak calistir.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY push_only.sh push_test.mjs $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash push_only.sh'
set -euo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
MGR=d28b7879-b34f-4de5-bd44-25e64e2ca734
[ -f push_test.mjs ] || { echo "HATA: push_test.mjs yok (scp?)"; exit 1; }

echo "[1] Push token'lari cekiliyor..."
$PSQL -t -A -c "SELECT COALESCE(json_agg(json_build_object('token',token,'platform',platform)),'[]') FROM bi_push_token WHERE user_id='$MGR';" > _toks.json
echo -n "  token json (ilk 80): "; head -c 80 _toks.json; echo

CID="$(docker compose ps -q krb-assessment)"
echo "[2] Kopyala + izin..."
docker cp push_test.mjs "$CID":/tmp/push_test.mjs
docker cp _toks.json "$CID":/tmp/_toks.json
docker exec -u root "$CID" chmod 0644 /tmp/push_test.mjs /tmp/_toks.json || true
echo "[3] GERCEK push (root olarak) gonderiliyor..."
docker exec -u root "$CID" node /tmp/push_test.mjs /tmp/_toks.json "💬 Yeni mesaj" "Uğur Yıldız: Test bildirimi 🚀"
rm -f _toks.json
echo "[BITTI] Telefonlarda bildirim gormelisin (OK olanlar icin)."
