#!/usr/bin/env bash
# YETKI_FAZ0 — Temizlik: REP_PARITE_V1 + FIX1 geri al (server_container.mjs + shells/saha.js).
#   Canlıyı son-iyi (pre-REP_PARITE) hâle döndürür. Reps kart iç bölümlerini Faz 1'e kadar görmez (kasıtlı).
#   Rollback'li, tek build, idempotent (iz yoksa atlar).
# KULLANIM: scp -i $KEY deploy_yetki_faz0.sh patch_yetki_faz0_revert_server.py patch_yetki_faz0_revert_client.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz0.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; MOB=shells/saha.js
[ -f "$SRV" ] && [ -f "$MOB" ] || { echo "HATA: kaynak yok"; exit 1; }
[ -f patch_yetki_faz0_revert_server.py ] && [ -f patch_yetki_faz0_revert_client.py ] || { echo "HATA: patch yok"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $SRV.bak.$TS + $MOB.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_yetki_faz0_revert_server.py "$SRV" || { rollback; exit 1; }
python3 patch_yetki_faz0_revert_client.py "$MOB" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA node srv"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA node cli"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/faz0_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/faz0_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server REP_PARITE izi (0 beklenir): "; docker exec "$CID" grep -c REP_PARITE /app/server.mjs || true
echo -n "[dogrula] client REP_PARITE izi (0 beklenir): "; docker exec "$CID" grep -c REP_PARITE /app/shells/saha.js || true
echo -n "[dogrula] kart manager kapisi geri geldi mi (mus-skor guard, >0 beklenir): "; docker exec "$CID" grep -c '"manager","admin"\].includes(S.role) && m.musteri_kodu) ? .<div id="mus-skor"' /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ0','Temizlik: REP_PARITE_V1 + FIX1 geri alindi (server + saha.js). Kart ic bolumleri son-iyi hale (manager/admin) dondu; gomulu true ve hardcode bypass kaldirildi. Diff ile pre-REP_PARITE ile birebir dogrulandi.','Yetki modulu v2 (derive-yetki-toparlama.md) icin temiz zemin. Hardcode drift matris disiplinine aykiriydi. Faz 1 bu kapilari musterikart capability + tek choke point ile duzgun kuracak.','{"marker":"YETKI_FAZ0","tur":"temizlik","plan":"derive-yetki-toparlama.md","geri_alinan":["REP_PARITE_V1","REP_PARITE_FIX1"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ0');
SELECT count(*) faz0 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ0';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ0 CANLI — temiz zemin. iPhone: uygulamayi oldur-ac (client degisti)."
