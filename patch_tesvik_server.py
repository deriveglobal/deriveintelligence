#!/usr/bin/env python3
# FINANS_TESVIK_WIN_V1 — /api/bi/finans/oda JSON'a "markalardan kazanilan tesvik/prim" ekler.
# Kaynak: bi_satis_faturalari kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM), YALNIZ muhatap=TEDARIKCI
# (bi_musteri_risk.grup ILIKE '%TEDAR%' — Brisa/Bridgestone + OLT/Continental). fatura_tarihi penceresi seciciye yanit verir.
# Idempotent, .bak, count==1 assert, node --check (deploy scriptinde).
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()

if "FINANS_TESVIK_WIN_V1" in src:
    print("SKIP (zaten var)"); sys.exit(0)

old = ('      const sizinti = { tutar: N(_sz.tutar), kalem: N(_sz.kalem), pct: N(_sz.pct) };\n'
       '      const data = { as_of: _a ? _a.a : null, win: _win, core, stok, gecikmis, marka, catal, kar, trend, pencere, sizinti, aging: null, motor_trend: null };')
new = ('      const sizinti = { tutar: N(_sz.tutar), kalem: N(_sz.kalem), pct: N(_sz.pct) };\n'
       '      /* FINANS_TESVIK_WIN_V1 — markalardan kazanilan tesvik/prim (DESTEK BEDELI+TUKETICI PRIM), YALNIZ muhatap=TEDARIKCI; fatura_tarihi penceresi seciciye yanit verir */\n'
       '      const _wf = (_win===\'buay\') ? "f.fatura_tarihi >= date_trunc(\'month\',CURRENT_DATE)" : (_win===\'yb\') ? "f.fatura_tarihi >= date_trunc(\'year\',CURRENT_DATE)" : "f.fatura_tarihi >= date_trunc(\'month\',CURRENT_DATE) - "+(_wn-1)+"*INTERVAL \'1 month\'";\n'
       '      const _tv = (await query("SELECT COALESCE(sum(f.satir_tutar),0)::float8 tutar, count(*)::int satir FROM bi_satis_faturalari f WHERE f.tenant_id::text=$1 AND f.kategori IN (\'DESTEK BEDELİ\',\'TÜKETİCİ PRİM\') AND EXISTS (SELECT 1 FROM bi_musteri_risk r WHERE r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu AND r.grup ILIKE \'%TEDAR%\') AND " + _wf, [String(T)])).rows[0] || {};\n'
       '      const tesvik = { tutar: M1(_tv.tutar), satir: N(_tv.satir) };\n'
       '      const data = { as_of: _a ? _a.a : null, win: _win, core, stok, gecikmis, marka, catal, kar, trend, pencere, sizinti, tesvik, aging: null, motor_trend: null };')

c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c})"
bak = PATH + ".bak_tesvik_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
src = src.replace(old, new)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: /oda JSON'a tesvik eklendi")
print("FINANS_TESVIK_WIN_V1 marker:", src.count("FINANS_TESVIK_WIN_V1"), "| tesvik key:", src.count("pencere, sizinti, tesvik, aging"))
