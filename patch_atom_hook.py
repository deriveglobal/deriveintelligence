#!/usr/bin/env python3
# OMURGA 39 — yukle endpoint'e marj atomu tazeleme (satış/alış yüklemesinde). snapshot hook'un yanına.
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
s=rd(SRV)

if 'metrik_marj_atom_uret' in s:
    print('  ⏭ zaten yamalı'); sys.exit(0)

ANCHOR = '''          } catch (e) { console.error("[yukle] snapshot:", e && e.message); tazelenen.push("⚠ OMURGA TAZELEME HATASI: " + String(e && e.message).slice(0,120)); }
        }'''
NEW = ANCHOR + '''
        // MARJ ATOMU (omurga_39) — satış/alış yüklemesinde kanonik SKU×ay marjı tazele
        if (sonuc.ok && ["satis_faturalari","stok_hareket"].includes(sonuc.tip)) {
          try {
            const _a = await query("SELECT metrik_marj_atom_uret($1::uuid) AS n", [session.tenantId]);
            tazelenen.push("marj atomu (" + (_a.rows[0]?.n ?? 0) + " satır)");
          } catch (e) { console.error("[yukle] marj_atom:", e && e.message); tazelenen.push("⚠ MARJ ATOM HATASI: " + String(e && e.message).slice(0,120)); }
        }'''

c = s.count(ANCHOR)
if c != 1:
    print(f'  ✗ anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
s = s.replace(ANCHOR, NEW, 1)
wr(SRV, s)
print('  ✅ marj atom hook eklendi (snapshot yanına)')

r=subprocess.run(['node','--check',SRV],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
s2=rd(SRV)
print('  hook   :', 'metrik_marj_atom_uret($1::uuid)' in s2)
print('  gate   :', '["satis_faturalari","stok_hareket"].includes(sonuc.tip)' in s2)
print('\n  ✅ YAMA TAMAM — sonra cron + docker build')
