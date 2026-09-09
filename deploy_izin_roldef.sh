#!/usr/bin/env bash
# IZIN_ROLDEF — Rapor alt-sekme izinleri: admin bypass + guard satirlari full-locked +
#   kayit yoksa ROL VARSAYILANI (rep=rotam, manager=hepsi). IZIN_YENIMODUL ustune. Tek build.
# KULLANIM (deriveapp klasoru):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_izin_roldef.sh patch_izin_roldef_shells.py patch_izin_roldef_tadmin.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_izin_roldef.sh'
set -euo pipefail
cd /opt/krb-assessment
TAD=shells/tenant-admin.js; DSK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$TAD" "$DSK" "$MOB" patch_izin_roldef_shells.py patch_izin_roldef_tadmin.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
grep -q IZIN_YENIMODUL_V1     "$TAD" || { echo "HATA: once IZIN_YENIMODUL_V1 (tadmin) olmali"; exit 1; }
grep -q IZIN_YENIMODUL_DK_V1  "$DSK" || { echo "HATA: once IZIN_YENIMODUL_DK_V1 olmali"; exit 1; }
grep -q IZIN_YENIMODUL_MOB_V1 "$MOB" || { echo "HATA: once IZIN_YENIMODUL_MOB_V1 olmali"; exit 1; }

TS=$(date +%s)
cp -a "$TAD" "$TAD.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"
echo "[yedek] .bak.$TS"
rollback(){ echo "GERI AL"; cp -a "$TAD.bak.$TS" "$TAD"; cp -a "$DSK.bak.$TS" "$DSK"; cp -a "$MOB.bak.$TS" "$MOB"; }

python3 patch_izin_roldef_shells.py "$DSK" || { rollback; exit 1; }
python3 patch_izin_roldef_shells.py "$MOB" || { rollback; exit 1; }
python3 patch_izin_roldef_tadmin.py "$TAD" || { rollback; exit 1; }

for f in "$TAD" "$DSK" "$MOB"; do
  node --check "$f" || { echo "HATA node: $f"; rollback; exit 1; }
  cp "$f" /tmp/_chk.mjs; node --check /tmp/_chk.mjs || { echo "HATA esm: $f"; rollback; exit 1; }
done
echo "[ok] syntax (3 dosya)"

docker build -t krb-assessment:secure . >/tmp/roldef_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/roldef_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] shell roldef: "; docker exec "$CID" sh -c 'grep -c IZIN_ROLDEF_SH_V1 /app/shells/saha_desktop.js; grep -c IZIN_ROLDEF_SH_V1 /app/shells/saha.js' | tr '\n' ' '; echo
echo -n "[dogrula] matris roldef: "; docker exec "$CID" grep -c IZIN_ROLDEF_TAD_V1 /app/shells/tenant-admin.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Rep = Ozet+Rotam (Ciro/Risk gizli); manager = hepsi; admin = hepsi + matriste kilitli-dolu. Hard-refresh."
