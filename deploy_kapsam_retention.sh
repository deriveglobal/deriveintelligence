#!/usr/bin/env bash
# (c) KAPSAM_RETENTION_V1 — Kapsam listesine tekrar-alim rozeti (🔴 kayiyor / 🟢 sadik).
#   Server: kapsam sorgusuna h1r/h2r/vis12 CTE + mapRow.tk (additive). Masaustu+mobil: satir rozeti.
#   Idempotent + rollback. Tek build. Fingerprint gomulu.
# KULLANIM (deriveapp klasorunde):
#   scp -i $KEY deploy_kapsam_retention.sh patch_kapsam_retention_server.py patch_kapsam_retention_desktop.py patch_kapsam_retention_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_kapsam_retention.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$SRV" "$DSK" "$MOB"; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
for p in patch_kapsam_retention_server.py patch_kapsam_retention_desktop.py patch_kapsam_retention_mobile.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
grep -q 'path === "/api/saha/rapor/kapsam"' "$SRV" || { echo "HATA: server KAPSAM_V1 yok"; exit 1; }
grep -q KAPSAM_DK_V1  "$DSK" || { echo "HATA: masaustu KAPSAM_DK_V1 yok"; exit 1; }
grep -q KAPSAM_MOB_V1 "$MOB" || { echo "HATA: mobil KAPSAM_MOB_V1 yok"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_kapsam_retention_server.py  "$SRV" || { rollback; exit 1; }
python3 patch_kapsam_retention_desktop.py "$DSK" || { rollback; exit 1; }
python3 patch_kapsam_retention_mobile.py  "$MOB" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaustu node"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA mobil node"; rollback; exit 1; }
cp "$DSK" /tmp/_d.mjs; node --check /tmp/_d.mjs || { echo "HATA esm masaustu"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm mobil"; rollback; exit 1; }
echo "[ok] syntax (server + masaustu + mobil)"
docker build -t krb-assessment:secure . >/tmp/kr_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kr_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server  KAPSAM_RETENTION_V1: "; docker exec "$CID" grep -c KAPSAM_RETENTION_V1 /app/server.mjs || true
echo -n "[dogrula] masaustu KAPSAM_RETENTION_V1: "; docker exec "$CID" grep -c KAPSAM_RETENTION_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil   KAPSAM_RETENTION_V1: "; docker exec "$CID" grep -c KAPSAM_RETENTION_V1 /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint SQL sorunlu"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'KAPSAM_RETENTION_V1',
 'Kapsam raporu musteri satirlarina tekrar-alim rozeti: 🔴 kayiyor (onceki 6 ay aldi, son 6 ay yok) / 🟢 sadik (son 6 ay aldi). Server kapsam sorgusuna h1r/h2r/vis12 CTE + mapRow.tk; masaustu+mobil satir rozeti.',
 'Saha ROI retention sinyalini rep akisina (Kapsam listesi) tasi — beyaz-alan + kayiyor = cifte acil. (c) adimi.',
 '{"marker":"KAPSAM_RETENTION_V1","alan":"tk{vc,durum}","surface":["kapsam-liste-masaustu","kapsam-liste-mobil"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='KAPSAM_RETENTION_V1');
UPDATE bi_yetenek SET
  ne_ise_yarar = COALESCE(ne_ise_yarar,'') || ' + Satir tekrar-alim rozeti (KAPSAM_RETENTION_V1): kayiyor/sadik, son 12 ay ziyaret.',
  guncellendi_at=now(), son_gorulme=now()
WHERE ad='saha_rapor_kapsam' AND ne_ise_yarar NOT LIKE '%KAPSAM_RETENTION_V1%';
SELECT 'insa_gunlugu' k, count(*) n FROM bi_insa_gunlugu WHERE adim='KAPSAM_RETENTION_V1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] KAPSAM_RETENTION_V1 CANLI — Kapsam listesinde tekrar-alim rozeti (masaustu+mobil). Hard-refresh."
