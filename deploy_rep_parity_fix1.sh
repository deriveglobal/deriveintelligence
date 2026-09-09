#!/usr/bin/env bash
# REP_PARITE_FIX1 — kartta görünen "/* REP_PARITE_V1 */" yazısını gizler (yalnız saha.js). Rollback'li.
# KULLANIM: scp -i $KEY deploy_rep_parity_fix1.sh patch_rep_parity_fix1.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rep_parity_fix1.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] && [ -f patch_rep_parity_fix1.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "REP_PARITE_V1" "$MOB" || { echo "HATA: önce REP_PARITE_V1 olmalı"; exit 1; }
TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
python3 patch_rep_parity_fix1.py "$MOB" || { cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
node --check "$MOB" || { echo "HATA node"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/pfix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/pfix_build.log; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] görünür yorum kaldı mı (0 beklenir): "; docker exec "$CID" sh -c "grep -c ': \"\"}  /\* REP_PARITE_V1 \*/' /app/shells/saha.js" || true
echo -n "[dogrula] FIX1: "; docker exec "$CID" grep -c REP_PARITE_FIX1 /app/shells/saha.js || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'REP_PARITE_FIX1','REP_PARITE_V1 /* */ yorumlari sablon HTML icine dusmus, kartta yazi olarak gorunuyordu; HTML yorumuna cevrildi.','Canli kartta "/* REP_PARITE_V1 */" metni goruldu (DEMMER MERMER). Sablon literali icine yorum konulmamali.','{"marker":"REP_PARITE_FIX1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='REP_PARITE_FIX1');
SELECT count(*) fix FROM bi_insa_gunlugu WHERE adim='REP_PARITE_FIX1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] REP_PARITE_FIX1 CANLI — yazı gizlendi. iPhone: öldür-aç."
