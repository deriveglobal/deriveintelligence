#!/usr/bin/env python3
# KADERI_FN_MAP_V1 — sistem haritasi ON-SIPARIS KADERI recetesine curated fonksiyon cagri talimati.
# Asistan elle agir SQL kurup durmasin/yanlis pencere secmesin -> onsiparis_kaderi(tenant) cagirsin.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
if "onsiparis_kaderi(tenant_id) fonksiyonunu" in src:
    print("SKIP (zaten var)"); sys.exit(0)

OLD = r'''Yalniz oznenin kendi kitabi spekulatif risktir; musteri on-taahhudu zaten satilmistir.'''
NEW = r'''Yalniz oznenin kendi kitabi spekulatif risktir; musteri on-taahhudu zaten satilmistir. Bu analizi ELLE SQL ile kurma (agir cok-CTE, yanlis pencere/grain riski -> imkansiz sayi uretebilirsin); onsiparis_kaderi(tenant_id) fonksiyonunu cagir: SELECT marka, ebat, commit_adet, beklenen, fazla_adet, ratio, buyume_g FROM onsiparis_kaderi(tenant_kimligi) WHERE fazla_adet>0 ORDER BY fazla_adet DESC. Kanonik dogrulanmis mantik: yalniz Ekim-Subat kis, sadece lastik, adet-bazli buyume-ayarli, normalize ebat, KRB-kendi taahhut. buyume_g isletmenin kis YoY buyumesi (~1,1). Ozet icin sum(commit_adet)/sum(fazla_adet).'''

c = src.count(OLD); assert c == 1, f"ANCHOR COUNT != 1 ({c})"
bak = PATH + ".bak_kaderimap_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
src = src.replace(OLD, NEW)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: kaderi fonksiyon cagri talimati eklendi")
print("marker:", src.count("onsiparis_kaderi(tenant_id) fonksiyonunu"))
