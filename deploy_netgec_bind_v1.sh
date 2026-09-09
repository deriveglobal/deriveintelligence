#!/usr/bin/env bash
# deploy_netgec_bind_v1.sh — Finans NET gecikmis call-site'larini KANONA (v_net_gecikmis_musteri) bagla.
#   _g (kart+konsantrasyon) · ov (liste) · _q (isim arama) · _oSql (sirali) → hepsi view'dan NET okur.
#   Cikti sekli AYNI. Risk MAX/harita/dso-top DOKUNULMADI (ayri, net'e sirayla cekilecek).
# ONKOSUL: v_net_gecikmis_musteri CANLI.
# SUNUCUDA:  cd /opt/krb-assessment && bash deploy_netgec_bind_v1.sh
# node --check + COKME testi + OTOMATIK ROLLBACK. Yedek: server_container.mjs.bak_netgec_<ts>
set -euo pipefail
TS=$(date +%Y%m%d_%H%M%S)
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

echo "== [0] onkosul: v_net_gecikmis_musteri =="
VOK=$(docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT count(*) FROM pg_views WHERE viewname='v_net_gecikmis_musteri';")
if [ "$VOK" != "1" ]; then echo "  !!! v_net_gecikmis_musteri YOK — once kanon_net_gecikmis_view.sql calistir. DURDU."; exit 1; fi
echo "  v_net_gecikmis_musteri: var"

echo "== [1] server yedegi =="
cp server_container.mjs "server_container.mjs.bak_netgec_$TS"
echo "  yedek: server_container.mjs.bak_netgec_$TS"

echo "== [2] patch yaz + uygula =="
cat > /opt/krb-assessment/_patch_netgec_bind.py <<'PY_EOF'
import sys
F="/opt/krb-assessment/server_container.mjs"
s=open(F,encoding="utf-8").read()
GUARD="SELECT muhatap_adi ad, net_gecikmis net, brut_gecikmis gross FROM v_net_gecikmis_musteri"
if GUARD in s:
    print("[netgec-bind] ZATEN BAGLI — atlaniyor"); sys.exit(0)

reps=[
 ("_g",
  "WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, muhatap_adi ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu) SELECT r.ad, GREATEST(r.vg+COALESCE(cb.borc,0),0) net, r.vg gross FROM r LEFT JOIN cb ON cb.musteri_kodu=r.kod WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%'",
  "SELECT muhatap_adi ad, net_gecikmis net, brut_gecikmis gross FROM v_net_gecikmis_musteri WHERE tenant_id::text=$1"),
 ("ov",
  "WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi, GREATEST(hesap_bakiyesi,0) bak, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu) SELECT r.muhatap_kodu kod, r.ad, GREATEST(r.vg+COALESCE(cb.borc,0),0)::float8 net FROM r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%'",
  "SELECT muhatap_kodu kod, muhatap_adi ad, net_gecikmis::float8 net FROM v_net_gecikmis_musteri WHERE tenant_id::text=$1"),
 ("_q",
  "WITH ov AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, muhatap_adi ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu) SELECT COALESCE(SUM(GREATEST(o.vg+COALESCE(cb.borc,0),0)),0)::float8 net FROM ov o LEFT JOIN cb ON cb.musteri_kodu=o.kod WHERE o.musteri_mi AND o.muhatap_adi ILIKE $2||'%'",
  "SELECT COALESCE(SUM(net_gecikmis),0)::float8 net FROM v_net_gecikmis_musteri WHERE tenant_id::text=$1 AND muhatap_adi ILIKE $2||'%'"),
 ("_oSql",
  "WITH ov AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu), n AS (SELECT o.ad, GREATEST(o.vg+COALESCE(cb.borc,0),0) net FROM ov o LEFT JOIN cb ON cb.musteri_kodu=o.kod WHERE o.musteri_mi AND o.grup NOT ILIKE '%TEDAR%') SELECT ad, net FROM n WHERE net>0 ORDER BY net DESC",
  "SELECT muhatap_adi ad, net_gecikmis net FROM v_net_gecikmis_musteri WHERE tenant_id::text=$1 AND net_gecikmis>0 ORDER BY net_gecikmis DESC"),
]

for ad,o,n in reps:
    c=s.count(o)
    if c!=1:
        print("[netgec-bind] %s eslesme=%d (1 olmali) — DURDU, dokunulmadi"%(ad,c)); sys.exit(2)
for ad,o,n in reps:
    s=s.replace(o,n,1)
open(F,"w",encoding="utf-8").write(s)
print("[netgec-bind] OK — _g/ov/_q/_oSql net gecikmis kanona (v_net_gecikmis_musteri) baglandi")
PY_EOF
python3 /opt/krb-assessment/_patch_netgec_bind.py || { echo "patch DURDU — rollback"; cp "server_container.mjs.bak_netgec_$TS" server_container.mjs; exit 1; }

echo "== [3] node --check =="
if node --check server_container.mjs; then echo "  server OK"; else echo "  FAIL — rollback"; cp "server_container.mjs.bak_netgec_$TS" server_container.mjs; exit 1; fi
echo "  v_net_gecikmis_musteri ref: $(grep -c v_net_gecikmis_musteri server_container.mjs) (>=4 bekle)"

echo "== [4] build + restart =="
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment

echo "== [5] container + COKME =="
echo "  container: $(docker ps --filter name=krb-assessment --format '{{.Status}}')"
HS=$(docker logs --since 90s krb-assessment 2>&1 | grep -c ERR_HTTP_HEADERS_SENT || true)
echo "  ERR_HTTP_HEADERS_SENT: $HS"
if [ "$HS" != "0" ]; then echo "  !!! COKME — ROLLBACK"; cp "server_container.mjs.bak_netgec_$TS" server_container.mjs; docker build -t krb-assessment:secure . >/dev/null 2>&1 && docker compose up -d --force-recreate krb-assessment; echo "geri alindi"; exit 1; fi

echo "== [6] canli DB-hakikat — kanon net (finans yuzeyleri artik bunu okuyor) =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT round(sum(net_gecikmis)/1e6,1) net_M, round(sum(brut_gecikmis)/1e6,1) brut_M, count(*) FILTER (WHERE net_gecikmis>0) gecikmis_musteri FROM v_net_gecikmis_musteri WHERE tenant_id::text='$T';"

echo "== [7] fingerprint =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL_EOF'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'NET_GECIKMIS_BIND_V1',
 'Finans net gecikmis call-site''lari KANONA baglandi: _g (kart+konsantrasyon top-6), ov (musteri liste), _q (isim arama toplam), _oSql (sirali liste) artik v_net_gecikmis_musteri okuyor (kendi DISTINCT ON + MIN-tum-tarih mahsup hesabi yerine). Ciktilar ayni sekil (ad/net/gross vb.). Karar (Fatih): net kanon, her yerde net 53,4.',
 'Net gecikmis ~15+ yerde farkli hesaplaniyordu; kanon v_net_gecikmis_musteri (53,4M). Bu adim finansin net yuzeylerini tek kaynaga cekti; kalan brut (risk MAX/harita/dso-top) sirayla net e cekilecek.',
 '{"marker":"NET_GECIKMIS_BIND_V1","kaynak":"v_net_gecikmis_musteri","baglanan":["_g","ov","_q","_oSql"],"karar":"net","deger_net_M":53.4,"kalan":["risk MAX raporlari","harita il/cari","_dsoSql/_topSql (bakiye ile ic ice)"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='NET_GECIKMIS_BIND_V1');
SQL_EOF
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT adim FROM bi_insa_gunlugu WHERE adim='NET_GECIKMIS_BIND_V1';"
echo "== BITTI — Finans net gecikmis KANONA bagli (v_net_gecikmis_musteri) =="
