#!/usr/bin/env bash
# deploy_hotfix_uuid.sh — ACIL: finans-oda + kokpit-umbrella "operator does not exist: text = uuid"
#   Sebep: v_marj_cari_ay okumalari `WHERE tenant_id=$1::uuid` (param formu) -> view.tenant_id runtime'da text -> patliyor.
#   Fix: `tenant_id::text=$1` (text=text, tip ne olursa olsun calisir). 2 yer (finans _am, kokpit _clm).
# SUNUCUDA:  cd /opt/krb-assessment && bash deploy_hotfix_uuid.sh
set -euo pipefail
TS=$(date +%Y%m%d_%H%M%S)
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

echo "== [T] v_marj_cari_ay.tenant_id tipi (bilgi) =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT pg_typeof(tenant_id) FROM v_marj_cari_ay LIMIT 1;" || true

echo "== [1] yedek =="
cp server_container.mjs "server_container.mjs.bak_hotfix_$TS"

echo "== [2] patch =="
cat > /opt/krb-assessment/_patch_hotfix_uuid.py <<'PY_EOF'
import sys
F=sys.argv[1] if len(sys.argv)>1 else "/opt/krb-assessment/server_container.mjs"
s=open(F,encoding="utf-8").read()
old="FROM v_marj_cari_ay WHERE tenant_id=$1::uuid"
new="FROM v_marj_cari_ay WHERE tenant_id::text=$1"
c=s.count(old)
if c==0 and s.count(new)>=1:
    print("[hotfix] ZATEN DUZELTILMIS — atlaniyor"); sys.exit(0)
if c!=2:
    print("[hotfix] beklenen 2 eslesme, bulunan=%d — DURDU"%c); sys.exit(2)
s=s.replace(old,new)
open(F,"w",encoding="utf-8").write(s)
print("[hotfix] OK — v_marj_cari_ay okumalari tenant_id::text=$1 yapildi (2 yer)")
PY_EOF
python3 /opt/krb-assessment/_patch_hotfix_uuid.py || { echo "patch DURDU — rollback"; cp "server_container.mjs.bak_hotfix_$TS" server_container.mjs; exit 1; }

echo "== [3] node --check =="
node --check server_container.mjs || { echo "FAIL — rollback"; cp "server_container.mjs.bak_hotfix_$TS" server_container.mjs; exit 1; }

echo "== [4] build + restart =="
docker build -t krb-assessment:secure . >/dev/null
docker compose up -d --force-recreate krb-assessment

echo "== [5] 8sn bekle, endpointleri canli dene =="
sleep 8
echo "  --- finans-oda + kokpit-umbrella son loglar (text = uuid GORULMEMELI) ---"
docker logs --since 60s krb-assessment 2>&1 | grep -E 'finans-oda|kokpit-umbrella|text = uuid' | tail -15 || echo "  (ilgili log yok — iyi)"
NEWERR=$(docker logs --since 60s krb-assessment 2>&1 | grep -c 'text = uuid' || true)
echo "  text = uuid sayisi (son 60sn): $NEWERR"
echo "  container: $(docker ps --filter name=krb-assessment --format '{{.Status}}')"
echo "== BITTI — hotfix uygulandi. Sayfalari (finans + kokpit) yenile/kapat-ac. Log temizse metrikler geri gelir. =="
