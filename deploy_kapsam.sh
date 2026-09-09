#!/usr/bin/env bash
# KAPSAM — Kapsam & Beyaz Alan raporu (yönetici): DDL (aksiyon/öğrenme tablosu) + server (3 uç +
#   dept map) + matris kaydı + masaüstü sekme. Mobil = ayrı artım. Tek build.
# KULLANIM (deriveapp klasoru):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_kapsam.sh ddl_kapsam_aksiyon.sql patch_kapsam_server.py patch_kapsam_tadmin.py patch_kapsam_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_kapsam.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; TAD=shells/tenant-admin.js; DSK=shells/saha_desktop.js
for f in "$SRV" "$TAD" "$DSK" ddl_kapsam_aksiyon.sql patch_kapsam_server.py patch_kapsam_tadmin.py patch_kapsam_desktop.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
grep -q IZIN_SAHAMAP_V1  "$SRV" || { echo "HATA: server tabani (IZIN_SAHAMAP_V1) yok"; exit 1; }
grep -q IZIN_YENIMODUL_V1 "$TAD" || { echo "HATA: tenant-admin tabani yok"; exit 1; }
grep -q "const RENDER = { ozet: rpOzet" "$DSK" || { echo "HATA: masaustu RENDER tabani yok"; exit 1; }

# 1) DDL — aksiyon/öğrenme tablosu (idempotent)
PG="$(docker compose ps -q krb-assessment-postgres || docker ps -qf name=krb-assessment-postgres | head -1)"
[ -n "$PG" ] || { echo "HATA: postgres konteyneri yok"; exit 1; }
echo "[ddl] saha_musteri_aksiyon…"
docker exec -i "$PG" sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < ddl_kapsam_aksiyon.sql && echo "[ddl] ok" || { echo "DDL HATASI"; exit 1; }

# 2) kod yamaları
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$TAD" "$TAD.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERI AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$TAD.bak.$TS" "$TAD"; cp -a "$DSK.bak.$TS" "$DSK"; }
python3 patch_kapsam_server.py  "$SRV" || { rollback; exit 1; }
python3 patch_kapsam_tadmin.py  "$TAD" || { rollback; exit 1; }
python3 patch_kapsam_desktop.py "$DSK" || { rollback; exit 1; }
for f in "$SRV" "$TAD" "$DSK"; do
  node --check "$f" || { echo "HATA node: $f"; rollback; exit 1; }
  cp "$f" /tmp/_c.mjs; node --check /tmp/_c.mjs || { echo "HATA esm: $f"; rollback; exit 1; }
done
echo "[ok] syntax (3 dosya)"

docker build -t krb-assessment:secure . >/tmp/kapsam_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kapsam_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server KAPSAM: "; docker exec "$CID" grep -c KAPSAM_V1 /app/server.mjs || true
echo -n "[dogrula] matris kapsam: "; docker exec "$CID" grep -c KAPSAM_TAD_V1 /app/shells/tenant-admin.js || true
echo -n "[dogrula] masaustu tab: ";  docker exec "$CID" grep -c KAPSAM_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] tablo: ";         docker exec -i "$PG" sh -c 'psql -tA -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT to_regclass('"'"'saha_musteri_aksiyon'"'"')"' || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Yönetici Rapor'da '📍 Kapsam' sekmesi. İzinler'de 'Kapsam & Beyaz Alan' verilebilir. Mobil ayrı artımda. Hard-refresh."
