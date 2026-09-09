#!/usr/bin/env bash
# BUGUN_FIXES — iki duzeltme birlikte:
#   1) BUGUN_TEKLIF_FIX_V1 (server_container.mjs): teklifler sorgusu t.musteri_adi kolon
#      hatasiyla cokuyordu -> Acik Teklif / Bekleyen Teklifler 0. JOIN ile duzeltilir.
#   2) BUGUN_ZIYARET_TIKLA_V1 (shells/saha_desktop.js): Bugun'de ziyarete tiklayinca
#      o ziyaretin detayi acilir (eskiden Ziyaretler sekmesine gidiyordu).
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_bugun_fixes.sh patch_bugun_teklif_fix.py patch_bugun_ziyaret_tikla.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_bugun_fixes.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
DSK=shells/saha_desktop.js
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_bugun_teklif_fix.py ] || { echo "HATA: teklif patch yok (scp?)"; exit 1; }
[ -f patch_bugun_ziyaret_tikla.py ] || { echo "HATA: tikla patch yok (scp?)"; exit 1; }

# 1) server teklif fix
if grep -q 'BUGUN_TEKLIF_FIX_V1' "$SRV"; then
  echo "[bilgi] $SRV zaten yamali"
else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_bugun_teklif_fix.py "$SRV"
  node --check "$SRV" && echo "[ok] node --check $SRV" || { echo "HATA node $SRV; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi

# 2) desktop tikla fix
if grep -q 'BUGUN_ZIYARET_TIKLA_V1' "$DSK"; then
  echo "[bilgi] $DSK zaten yamali"
else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_bugun_ziyaret_tikla.py "$DSK"
  node --check "$DSK" && echo "[ok] node --check $DSK" || { echo "HATA node $DSK; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/bugunfix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/bugunfix_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c BUGUN_TEKLIF_FIX_V1 /app/server.mjs || true
echo -n "[dogrula] desktop marker: "; docker exec "$CID" grep -c BUGUN_ZIYARET_TIKLA_V1 /app/shells/saha_desktop.js || true
echo "[dogrula] bekleyen teklif sayisi (5 bekleniyor):"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT count(*) AS bekleyen FROM saha_teklif WHERE durum IN ('TASLAK','ONAY_BEKLIYOR');" || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hard-refresh -> Acik Teklif/Bekleyen Teklifler 5 gostermeli; Bugun'de ziyarete tiklayinca detay acilmali."
