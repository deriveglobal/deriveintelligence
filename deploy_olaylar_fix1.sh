#!/usr/bin/env bash
# MUSTERI_OLAYLAR_FIX1 — /olaylar cr sorgusu uuid=text düzeltmesi (yalnız server). Rollback'li.
# KULLANIM: scp -i $KEY deploy_olaylar_fix1.sh patch_olaylar_fix1.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_olaylar_fix1.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_olaylar_fix1.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "MUSTERI_OLAYLAR_V1" "$SRV" || { echo "HATA: önce MUSTERI_OLAYLAR_V1 olmalı"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_olaylar_fix1.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
node --check "$SRV" || { echo "HATA node"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/fix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/fix_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] FIX1: "; docker exec "$CID" grep -c MUSTERI_OLAYLAR_FIX1 /app/server.mjs || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_OLAYLAR_FIX1','/olaylar cr sorgusu m.tenant_id::text=$1::text (uuid=text tuzagi; sg.tenant_id=$1::text $1 i text sabitliyordu, m.tenant_id=$1 patliyordu).','Canli 500: operator does not exist uuid=text. Devir kurali: tum tenant karsilastirmalari ::text.','{"marker":"MUSTERI_OLAYLAR_FIX1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_OLAYLAR_FIX1');
SELECT count(*) fix FROM bi_insa_gunlugu WHERE adim='MUSTERI_OLAYLAR_FIX1';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] MUSTERI_OLAYLAR_FIX1 CANLI — kart istihbarat başlığı artık dolmalı. Hard-refresh."
