#!/usr/bin/env python3
# CEO_ODA_AUTO_V1 — CEO sistem prompt'undaki sabit "5 oda ... Veri" satirini KALDIRIR ve odalari
# selfCtx'ten (bi_yetenek tur='yuzey', canli) otomatik turetir. Yeni oda = sadece tur=yuzey bi_yetenek
# satiri; prompt bir daha elle guncellenmez. Idempotent + .bak + node --check + rollback. TEK build.
# KULLANIM: /opt/krb-assessment/ icine koy →
#   cd /opt/krb-assessment && python3 patch_ceo_oda_auto.py \
#     && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SV='/opt/krb-assessment/server_container.mjs'
EDITS=[("            '\\nSon yapilan isler (insa gunlugu):\\n' +", '            \'\\nGUNCEL ODALAR/YUZEYLER (canli, bu defterden — SABIT LISTE TUTMA): \' + (_y.rows.filter(function(r){return r.tur==="yuzey";}).map(function(r){return r.ad;}).join(\' · \') || \'(yuzey isaretli kayit yok)\') + \'\\n\' +\n            \'\\nSon yapilan isler (insa gunlugu):\\n\' +'), ('- ODA YAPISI (guncel, 5 oda): Kokpit (ana) · CEO Assistant (sen) · Fiyat · Rakip Fiyatlari · Veri. Eski departmanlar (Satis/Fiyatlandirma/Depo/Sistem/Siparis/Marka direktorleri) EMEKLI — onlara atif yapma.', '- ODALAR/YUZEYLER: SABIT LISTE TUTMA — guncel odalar/yuzeyler yukaridaki KENDINI TANI defterinden (bi_yetenek tur=yuzey, canli) gelir; yeni oda eklenince orada otomatik belirir. Eski departman odalari (Satis/Fiyatlandirma/Depo/Sistem/Siparis/Marka) EMEKLI.')]
GUARD="GUNCEL ODALAR/YUZEYLER (canli, bu defterden"
def nc(t):
    for ext in ("mjs","cjs"):
        p="/tmp/_ceoc."+ext; open(p,"w",encoding="utf-8").write(t)
        if subprocess.run(["node","--check",p],capture_output=True,text=True).returncode==0: return True,""
        e=subprocess.run(["node","--check",p],capture_output=True,text=True).stderr
    return False,e
src=open(SV,encoding="utf-8").read()
if GUARD in src:
    print("• zaten uygulanmis, atlandi."); sys.exit(0)
for old,new in EDITS:
    c=src.count(old)
    if c!=1: print("HATA anchor count=%d: %r — DUR."%(c,old[:55])); sys.exit(1)
    src=src.replace(old,new,1)
ok,err=nc(src)
if not ok: print("HATA node --check:\n"+err); sys.exit(1)
shutil.copy(SV,SV+".bak_ceooda"); open(SV,"w",encoding="utf-8").write(src)
print("✓ CEO prompt: sabit oda listesi kaldirildi, canli turetme eklendi.")
print("\nSimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
