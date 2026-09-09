#!/usr/bin/env python3
# omurga_77 — Trend panelinde GEÇEN YIL karsilastirmasi: kokpit-data trend sorgusu self-join ile
# her ayin 12 ay oncesini de dondurur (ciro_gy/stok_gy/dso_gy). Gecmis yoksa null -> cizgi cizilmez.
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

if "ciro_gy" in srv:
    sys.exit("ZATEN VAR: trend gy (ciro_gy) eklenmis.")
A = "const trend = (await query(`SELECT to_char(donem"
i = srv.find(A)
if i < 0:
    sys.exit("HATA: kokpit-data trend sorgusu bulunamadi (elle bak).")
j = srv.find(")).rows;", i)
if j < 0:
    sys.exit("HATA: trend sorgu sonu bulunamadi.")
j += len(")).rows;")

NEW = '''const trend = (await query(`WITH m AS (
          SELECT donem,
            max(deger) FILTER (WHERE metrik='ciro_lastik') c,
            max(deger) FILTER (WHERE metrik='stok_deger') s,
            max(deger) FILTER (WHERE metrik='dso') d
          FROM bi_metrik_gecmis WHERE tenant_id::text=$1 AND boyut_tipi='sirket' AND periyot='ay'
            AND donem>=(CURRENT_DATE - INTERVAL '25 months') GROUP BY donem)
        SELECT to_char(c.donem,'YY-MM') ay,
          round(c.c/1e6,1)::float8 ciro, round(c.s/1e6,1)::float8 stok, round(c.d)::int dso,
          round(p.c/1e6,1)::float8 ciro_gy, round(p.s/1e6,1)::float8 stok_gy, round(p.d)::int dso_gy
        FROM m c LEFT JOIN m p ON p.donem = (c.donem - INTERVAL '12 months')
        WHERE c.donem>=(CURRENT_DATE - INTERVAL '13 months') ORDER BY c.donem`, [T])).rows;'''

srv = srv[:i] + NEW + srv[j:]
shutil.copy2(S, S + ".trendgy.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".trendgy.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .trendgy.bak)")
print("OK: trend sorgusu geçen-yıl (ciro_gy/stok_gy/dso_gy) döndürüyor. kokpit.html -> shells/, sonra build.")
