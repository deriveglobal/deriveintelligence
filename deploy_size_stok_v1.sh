#!/usr/bin/env bash
# deploy_size_stok_v1.sh — size-opportunities (ebat) stok CTE'sine LASTIK% filtresi (kanon).
# SUNUCUDA: cd /opt/krb-assessment && bash deploy_size_stok_v1.sh
set -euo pipefail
TS=$(date +%Y%m%d_%H%M%S)
cp server_container.mjs "server_container.mjs.bak_sizestok_$TS"
cat > /opt/krb-assessment/_patch_size_stok.py <<'PY_EOF'
import sys
F=sys.argv[1] if len(sys.argv)>1 else "/opt/krb-assessment/server_container.mjs"
s=open(F,encoding="utf-8").read()
old="""        WHERE sd.tenant_id = $1::uuid
          AND sd.export_date = (SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id = $1::uuid)
        GROUP BY 1"""
new="""        WHERE sd.tenant_id = $1::uuid
          AND sd.grup_adi ILIKE 'LASTIK%'
          AND sd.export_date = (SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id = $1::uuid)
        GROUP BY 1"""
if new in s:
    print("[size-stok] ZATEN filtreli — atlaniyor"); sys.exit(0)
c=s.count(old)
if c!=1:
    print("[size-stok] eslesme=%d (1 olmali) — DURDU"%c); sys.exit(2)
s=s.replace(old,new,1)
open(F,"w",encoding="utf-8").write(s)
print("[size-stok] OK — size-opportunities stok CTE LASTIK% filtrelendi")
PY_EOF
python3 /opt/krb-assessment/_patch_size_stok.py || { echo "patch DURDU — rollback"; cp "server_container.mjs.bak_sizestok_$TS" server_container.mjs; exit 1; }
node --check server_container.mjs || { echo "node FAIL — rollback"; cp "server_container.mjs.bak_sizestok_$TS" server_container.mjs; exit 1; }
echo "  filtre ref: $(grep -c "AND sd.grup_adi ILIKE 'LASTIK%'" server_container.mjs)"
docker build -t krb-assessment:secure . >/dev/null
docker compose up -d --force-recreate krb-assessment
sleep 8
if docker logs --since 60s krb-assessment 2>&1 | grep -qE 'does not exist'; then echo "  !!! SQL HATASI — ROLLBACK"; cp "server_container.mjs.bak_sizestok_$TS" server_container.mjs; docker build -t krb-assessment:secure . >/dev/null 2>&1 && docker compose up -d --force-recreate krb-assessment; echo "geri alindi"; exit 1; fi
echo "  son 60sn hata: $(docker logs --since 60s krb-assessment 2>&1 | grep -ciE 'error|does not exist' || true) · $(docker ps --filter name=krb-assessment --format '{{.Status}}')"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL_EOF'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SIZE_STOK_LASTIK_V1',
 'size-opportunities (ebat firsatlari) stok CTE''sine grup_adi ILIKE LASTIK% eklendi -> ebat-bazli stok degeri resmen kanon (lastik). Onceden ebat-join ile efektif lastikti ama acik filtre yoktu.',
 'Stok kanon programi: ebat-stok da tek tanima. Regex-sizinti riskini de kapatir.',
 '{"marker":"SIZE_STOK_LASTIK_V1","yuzey":"/api/bi/orders/size-opportunities stok CTE","filtre":"grup_adi ILIKE LASTIK%"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SIZE_STOK_LASTIK_V1');
SQL_EOF
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT adim FROM bi_insa_gunlugu WHERE adim='SIZE_STOK_LASTIK_V1';"
echo "== BITTI — ebat/size stok LASTIK% kanon =="
