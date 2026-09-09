#!/usr/bin/env bash
# IZIN_YENIMODUL — Ciro / Risk Radarı / Bugün Sahada'yı Saha izin matrisine ayrı
#   verilebilir alt-araç yap (tenant-admin.js) + Rapor alt-sekmelerini geriye-uyumlu
#   kapıla (saha_desktop.js + saha.js). Tek build.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_izin_yenimodul.sh patch_izin_yenimodul_tadmin.py patch_izin_yenimodul_desktop.py patch_izin_yenimodul_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_izin_yenimodul.sh'
set -euo pipefail
cd /opt/krb-assessment
TAD=shells/tenant-admin.js; DSK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$TAD" "$DSK" "$MOB" patch_izin_yenimodul_tadmin.py patch_izin_yenimodul_desktop.py patch_izin_yenimodul_mobile.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
grep -q EKIP_YONETIM_V3   "$TAD" || { echo "HATA: tenant-admin EKIP_YONETIM_V3 yok"; exit 1; }
grep -q SABAH_ROTAM_DK_V1 "$DSK" || { echo "HATA: desktop SABAH_ROTAM_DK_V1 yok"; exit 1; }
grep -q SABAH_ROTAM_V1    "$MOB" || { echo "HATA: mobil SABAH_ROTAM_V1 yok"; exit 1; }

TS=$(date +%s)
cp -a "$TAD" "$TAD.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"
echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$TAD.bak.$TS" "$TAD"; cp -a "$DSK.bak.$TS" "$DSK"; cp -a "$MOB.bak.$TS" "$MOB"; }

python3 patch_izin_yenimodul_tadmin.py  "$TAD" || { rollback; exit 1; }
python3 patch_izin_yenimodul_desktop.py "$DSK" || { rollback; exit 1; }
python3 patch_izin_yenimodul_mobile.py  "$MOB" || { rollback; exit 1; }

for f in "$TAD" "$DSK" "$MOB"; do
  node --check "$f" || { echo "HATA node: $f"; rollback; exit 1; }
  cp "$f" /tmp/_chk.mjs; node --check /tmp/_chk.mjs || { echo "HATA esm: $f"; rollback; exit 1; }
done
echo "[ok] syntax (3 dosya)"

docker build -t krb-assessment:secure . >/tmp/izin_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/izin_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] matris config: "; docker exec "$CID" grep -c IZIN_YENIMODUL_V1    /app/shells/tenant-admin.js || true
echo -n "[dogrula] desktop kapı:  "; docker exec "$CID" grep -c IZIN_YENIMODUL_DK_V1  /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil kapı:    "; docker exec "$CID" grep -c IZIN_YENIMODUL_MOB_V1 /app/shells/saha.js || true
echo -n "[dogrula] yeni sütunlar: "; docker exec "$CID" grep -o '\["ciro", "Ciro"\], \["risk", "Risk Radarı"\], \["rotam", "Bugün Sahada"\]' /app/shells/tenant-admin.js | head -1 || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Yönetim › İzinler › Saha'da Ciro / Risk Radarı / Bugün Sahada sütunları çıkacak."
echo "        Not: mevcut kullanıcılar bir satırı Kaydet'leyene kadar eski görünümü korur (grandfather)."
