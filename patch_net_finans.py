#!/usr/bin/env python3
# NET_GECIKMIS_FINANS_V1 — legacy /api/bi/finans (deger agaci) gecikmis + gecikmis_musteri brut -> net (v_net_gecikmis_musteri).
# Son canli gross net-gecikmis yuzeyi. net_sermaye a.bakiye kullanir (gecikmis'i degil) -> guvenli, sadece display.
# $1::uuid tek baglam (endpoint tutarli). Idempotent, count==1.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
changes = []
def apply(name, new, old):
    global src
    if new in src:
        changes.append(f"SKIP (zaten var): {name}"); return
    c = src.count(old)
    assert c == 1, f"ANCHOR COUNT != 1 ({c}) : {name}"
    src = src.replace(old, new); changes.append(f"OK: {name}")

apply("finans gecikmis -> net",
  "                   (SELECT COALESCE(sum(net_gecikmis),0) FROM v_net_gecikmis_musteri WHERE tenant_id=$1::uuid) AS gecikmis,  /* NET_GECIKMIS_FINANS_V1 brut->net */",
  "                   COALESCE(sum(vadesi_gecmis),0)  AS gecikmis,")

apply("finans gecikmis_musteri -> net",
  "                   (SELECT count(*) FROM v_net_gecikmis_musteri WHERE tenant_id=$1::uuid AND net_gecikmis>0) AS gecikmis_musteri  /* NET_GECIKMIS_FINANS_V1 */",
  "                   count(*) FILTER (WHERE vadesi_gecmis>0) AS gecikmis_musteri")

if src == orig:
    print("DEGISIKLIK YOK")
else:
    bak = PATH + ".bak_netfinans_" + time.strftime("%Y%m%d_%H%M%S")
    shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    with open(PATH, "w", encoding="utf-8") as f: f.write(src)
for c in changes: print(" ", c)
print("NET_GECIKMIS_FINANS_V1 marker:", src.count("NET_GECIKMIS_FINANS_V1"))
