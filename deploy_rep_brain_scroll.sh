#!/usr/bin/env bash
# REP_BRAIN_SCROLL_V1 — Asistan ekraninda yukari kaydirinca ust icerigin gorunmemesi / ekranin
# basa donmesi hatasini duzeltir. Kok neden: document seviyesindeki pull-to-refresh handler asistan
# ekraninda #saha-main'i izliyordu (gercek kaydirici #rb-msgs, hep scrollTop=0) -> her asagi/yukari
# harekette yenilemeyi tetikleyip basa donuyordu. Cozum: asistan sarmalayicisina .rb-wrap + PTR sc()
# bu ekranda da null donsun (CEO sohbetiyle birebir ayni). Sadece shells/saha.js; native/rebuild YOK.
# KULLANIM (kendi Mac terminalinde):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_rep_brain_scroll.py deploy_rep_brain_scroll.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rep_brain_scroll.sh'
set -euo pipefail
cd /opt/krb-assessment
# CANLI dosya container'da /app/shells/saha.js olarak servis edilir -> kaynak shells/saha.js.
# (Kokte eski/stale bir ./saha.js olabilir; ONA DOKUNMA.)
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_rep_brain_scroll.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'function vRepBrain' "$F" || { echo "HATA: $F asistan icermiyor - yanlis dosya?"; exit 1; }
grep -q 'ceo-wrap' "$F" || { echo "HATA: $F PTR handler icermiyor - yanlis/eski dosya?"; exit 1; }
grep -q 'REP_AKTIVITE_HB' "$F" || echo "[UYARI] $F icinde heartbeat markeri yok - beklenen canli dosya bu olmayabilir; yine de devam."

TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_rep_brain_scroll.py "$F" || { echo "PATCH BASARISIZ (dosya yazilmadi, degisiklik yok)"; exit 1; }
node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check - geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/rbscroll_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/rbscroll_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c REP_BRAIN_SCROLL_V1 /app/shells/saha.js
echo "[BITTI] Asistan'i ac, uzun sohbette yukari kaydir -> ust mesajlar gorunmeli, ekran basa donmemeli. (Cmd+Shift+R / uygulamayi yeniden ac)"
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
