#!/usr/bin/env bash
# GUNLUK_RAPOR_EXEC — Yonetici gunluk raporu (5 bolum) + 08:00 zamanlayici + dry onizleme.
# KULLANIM (deriveapp klasorunde):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_gunluk_rapor_exec.sh patch_gunluk_rapor_exec.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_gunluk_rapor_exec.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_gunluk_rapor_exec.py ] || { echo "HATA: patch yok"; exit 1; }
if grep -q GUNLUK_RAPOR_EXEC_V1 "$SRV"; then
  echo "[bilgi] $SRV zaten yamali"
else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_gunluk_rapor_exec.py "$SRV"
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
  cp "$SRV" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/rx_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rx_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c GUNLUK_RAPOR_EXEC_V1 /app/server.mjs || true
SECRET=$(docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -Atc "SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'" 2>/dev/null || true)
echo "[bilgi] alarm_flush_secret=$SECRET"
sleep 4
echo "===== DRY ÖNİZLEME (gönderMEZ — dünkü rapor özeti) ====="
docker exec "$CID" node -e "
fetch('http://localhost:3000/api/saha/gunluk-rapor-exec?key=$SECRET&dry=1')
 .then(r=>r.json()).then(j=>{
   const x=(j.results&&j.results[0])||{}; const v=x.veri||{};
   console.log(JSON.stringify({
     gun:x.gun,
     headline:x.ai&&x.ai.headline,
     finance:{tahsil:v.tahsil,gecikmis:v.gecikmis,vade:v.vade},
     sales:v.satis, kanal:v.kanal,
     customer:{ziyaret:(v.zk||{}).ziyaret,musteri:(v.zk||{}).musteri,tuk:(v.zk||{}).tuk,tic:(v.zk||{}).tic},
     field_voice:x.ai&&x.ai.field_voice, customer_ai:x.ai&&x.ai.customer, competitors:x.ai&&x.ai.competitors,
     ai_err:x.ai&&x.ai._err
   },null,2));
 }).catch(e=>console.log('ERR',e.message));
" || echo "(dry cagrisi calismadi — elle: curl '<host>/api/saha/gunluk-rapor-exec?key=$SECRET&dry=1')"
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Yonetici gunluk raporu canli. Her sabah 08:00 (Europe/Istanbul) otomatik; push+inbox+e-posta (GM+manager)."
