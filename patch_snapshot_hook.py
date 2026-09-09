#!/usr/bin/env python3
# OMURGA 22b — yukle endpoint'e metrik_snapshot_al hook (tip-kapılı + try/catch).
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)

HOOK = '''        // METRİK OMURGASI (omurga_22) — finans yüklemesinde trendin son noktasını ANINDA tazele.
        // Kendi-hakem: (1) sadece finans-ilgili tip'te çalış (alakasız yükleme boşa iş yapmasın),
        //   (2) try/catch — snapshot hatası yüklemeyi DÜŞÜRMESİN, tazelenen'e yaz.
        if (sonuc.ok && ["satis_faturalari","cari_bakiye","musteri_risk","stok_anlik","stok_hareket"].includes(sonuc.tip)) {
          try {
            await query("SELECT metrik_snapshot_al($1::uuid)", [session.tenantId]);
            tazelenen.push("metrik omurgası (trend güncel)");
          } catch (e) { console.error("[yukle] snapshot:", e && e.message); tazelenen.push("⚠ OMURGA TAZELEME HATASI: " + String(e && e.message).slice(0,120)); }
        }
'''
ANCHOR = '        sendJson(response, sonuc.ok ? 200 : 422, { dosya: dosyaAdi, boyut, ...sonuc, tazelenen, saglik });'
s=rd(SRV)
if 'metrik_snapshot_al($1::uuid)' in s:
    print('  ⏭ zaten yamalı')
else:
    if s.count(ANCHOR)!=1:
        print(f'  ✗ anchor {s.count(ANCHOR)} kez (1 bekleniyor) — DURDU'); sys.exit(1)
    s=s.replace(ANCHOR, HOOK+ANCHOR, 1)
    wr(SRV,s); print('  ✅ server: snapshot hook eklendi (tip-kapılı + try/catch)')

r=subprocess.run(['node','--check',SRV],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX');
if r.returncode!=0: print(r.stderr); sys.exit(1)
s2=rd(SRV)
print('  hook var :', 'metrik_snapshot_al($1::uuid)' in s2)
print('  gate var :', '"stok_hareket"].includes(sonuc.tip)' in s2)
print('\n  ✅ sonra: cron DRY (omurga_22b_cron_dry.sh) + docker build')
