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
