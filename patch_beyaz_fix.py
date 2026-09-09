#!/usr/bin/env python3
# MANAGER_PF_BEYAZ_FIX — param-tip düzeltmesi: beyaz WS'de tüm tenant karşılaştırmaları ::text=$1::text.
# Yalnız beyaz bloğuna dokunur (WS const + mm join, ikisi de benzersiz). Diğer uçlar etkilenmez.
# cd /opt/krb-assessment && python3 patch_beyaz_fix.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil
SRC="/opt/krb-assessment/server_container.mjs"
src=open(SRC,encoding="utf-8").read()

if "const WS = " not in src:
    print("HATA: beyaz WS bloğu yok (MANAGER_PF_BEYAZ_V1 uygulandı mı?). DUR."); sys.exit(1)

# 1) WS template'ini bul (benzersiz) ve tamamını düzeltilmişle değiştir
i = src.index("const WS = `")
j = src.index("`;", i) + 2
old_ws = src[i:j]
new_ws = '''const WS = `
    WITH satan AS (
      SELECT f.musteri_kodu, round(sum(f.satir_tutar))::bigint ciro
        FROM bi_satis_faturalari f
       WHERE f.tenant_id::text=$1::text AND f.satir_tutar>0 AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'
         AND f.grup_adi NOT IN ('PRİM HAKEDİŞLERİ','HAMMADDE','DURAN VARLIKLAR','ALINAN HIZMETLER')
       GROUP BY 1),
    b2b AS (
      SELECT s.musteri_kodu, s.ciro, r.grup
        FROM satan s JOIN bi_musteri_risk r ON r.tenant_id::text=$1::text AND r.muhatap_kodu=s.musteri_kodu
       WHERE r.grup IN ('FILO TICARI','FILO TUKETICI','TOPTAN','KURUM')),
    ws AS (
      SELECT b.* FROM b2b b
       WHERE NOT EXISTS (SELECT 1 FROM saha_musteri m
                          WHERE m.tenant_id::text=$1::text AND m.aktif AND m.musteri_kodu=b.musteri_kodu AND m.sorumlu_rep IS NOT NULL))`;'''
if old_ws == new_ws:
    print("• WS zaten düzeltilmiş.")
else:
    src = src.replace(old_ws, new_ws, 1)

# 2) master join'i düzelt (benzersiz: ws.musteri_kodu)
src = src.replace("mm.tenant_id=$1 AND mm.musteri_kodu=ws.musteri_kodu",
                  "mm.tenant_id::text=$1::text AND mm.musteri_kodu=ws.musteri_kodu")

shutil.copy(SRC, SRC+".bak_beyazfix")
open(SRC,"w",encoding="utf-8").write(src)
open("/tmp/_bzf.mjs","w",encoding="utf-8").write(src)
r=subprocess.run(["node","--check","/tmp/_bzf.mjs"],capture_output=True,text=True)
if r.returncode!=0:
    shutil.copy(SRC+".bak_beyazfix", SRC); print("HATA node --check:\n"+r.stderr); sys.exit(1)
print("✓ beyaz param-tip düzeltildi (::text=$1::text) + node --check geçti.")
print("Şimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
