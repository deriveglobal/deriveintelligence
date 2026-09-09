#!/usr/bin/env python3
# MANAGER_PF_MUSTERI_FILTRE_V1 — konsantrasyon+retention+sube+bolge+urun analizlerinden musteri-disi
# gruplari (TEDARIKCI/IMALATCI/PERSONEL/GRUP MUSTERILERI) NOT EXISTS anti-join ile cikarir.
# Idempotent (marker guard) + .bak + node --check + rollback. TEK build. (Client dokunulmadi.)
# KULLANIM: /opt/krb-assessment/ icine koy →
#   cd /opt/krb-assessment && python3 patch_musteri_filtre.py \
#     && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SV='/opt/krb-assessment/server_container.mjs'
EDITS=[("       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DGY} AND COALESCE(sube,'')<>''", "       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DGY} AND COALESCE(sube,'')<>'' AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=bi_satis_faturalari.tenant_id::text AND _mr.muhatap_kodu=bi_satis_faturalari.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))"), ("       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DGY} AND COALESCE(sehir,'')<>''", "       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DGY} AND COALESCE(sehir,'')<>'' AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=bi_satis_faturalari.tenant_id::text AND _mr.muhatap_kodu=bi_satis_faturalari.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))"), ('                 WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART} GROUP BY 1),', "                 WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART} AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=bi_satis_faturalari.tenant_id::text AND _mr.muhatap_kodu=bi_satis_faturalari.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI')) GROUP BY 1),"), ("       FROM master_musteri WHERE tenant_id=$1 AND kategori_kirilimi IS NOT NULL AND kategori_kirilimi <> '{}'::jsonb", "       FROM master_musteri WHERE tenant_id=$1 AND kategori_kirilimi IS NOT NULL AND kategori_kirilimi <> '{}'::jsonb AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=master_musteri.tenant_id::text AND _mr.muhatap_kodu=master_musteri.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))"), ('         WHERE f.tenant_id::text=$1::text AND f.satir_tutar>0 AND f.fatura_tarihi IS NOT NULL', "         WHERE f.tenant_id::text=$1::text AND f.satir_tutar>0 AND f.fatura_tarihi IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=f.tenant_id::text AND _mr.muhatap_kodu=f.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))"), ('      WHERE mm.tenant_id::text=$1::text AND extract(year from mm.ilk_fatura)::int=$2', "      WHERE mm.tenant_id::text=$1::text AND extract(year from mm.ilk_fatura)::int=$2 AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=mm.tenant_id::text AND _mr.muhatap_kodu=mm.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))"), ('                 WHERE f.tenant_id::text=$1::text AND f.satir_tutar>0 AND f.fatura_tarihi>=${DSTART}', "                 WHERE f.tenant_id::text=$1::text AND f.satir_tutar>0 AND f.fatura_tarihi>=${DSTART} AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=f.tenant_id::text AND _mr.muhatap_kodu=f.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))")]
GUARD="_mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI')"
def nc(t):
    for ext in ("mjs","cjs"):
        p="/tmp/_mfc."+ext; open(p,"w",encoding="utf-8").write(t)
        if subprocess.run(["node","--check",p],capture_output=True,text=True).returncode==0: return True,""
        e=subprocess.run(["node","--check",p],capture_output=True,text=True).stderr
    return False,e
src=open(SV,encoding="utf-8").read()
if src.count(GUARD)>=5:
    print("• zaten uygulanmis (>=5 filtre), atlandi."); sys.exit(0)
for i,(old,new) in enumerate(EDITS,1):
    c=src.count(old)
    if c!=1: print("HATA anchor #%d count=%d: %r — DUR."%(i,c,old[:55])); sys.exit(1)
    src=src.replace(old,new,1)
ok,err=nc(src)
if not ok: print("HATA node --check:\n"+err); sys.exit(1)
shutil.copy(SV,SV+".bak_musfiltre"); open(SV,"w",encoding="utf-8").write(src)
print("✓ 5 analize musteri-disi grup filtresi eklendi (7 sorgu).")
print("\nSimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
