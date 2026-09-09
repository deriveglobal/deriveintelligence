#!/usr/bin/env python3
# omurga_73-fix — cockpit HTML'ini /api/bi/kokpit'e tasi (SPA handler baypas) + bi.js iframe src duzelt.
# Yedekli + node --check'li + geri-alinabilir. Sunucuda calisir.
import re, shutil, subprocess, sys
REPO="/opt/krb-assessment"
S=f"{REPO}/server_container.mjs"; B=f"{REPO}/shells/bi.js"
srv=open(S,encoding="utf-8").read(); bijs=open(B,encoding="utf-8").read()

# 1) server: /kokpit -> /api/bi/kokpit
if 'url.pathname === "/api/bi/kokpit"' in srv:
    print("server: /api/bi/kokpit zaten var (atlandi)")
elif 'url.pathname === "/kokpit"' in srv:
    srv = srv.replace('url.pathname === "/kokpit"', 'url.pathname === "/api/bi/kokpit"', 1)
    print("server: /kokpit -> /api/bi/kokpit")
else:
    sys.exit("HATA: server'da /kokpit route yok — once ana patch calismali")

# 2) bi.js: finans odasi -> iframe(/api/bi/kokpit) + ciz_finans erken-return
if 'src="/api/bi/kokpit"' in bijs:
    print("bi.js: iframe zaten var (atlandi)")
else:
    pat = re.compile(r"_f\.innerHTML = '<div id=\"finans-govde\".*?</div>';")
    if not pat.search(bijs): sys.exit("HATA: bi.js finans-govde anchor yok")
    IFRAME = ('_f.innerHTML = \'<iframe id="kokpit-frame" src="/api/bi/kokpit" '
              'style="width:100%;height:100%;min-height:82vh;border:0;display:block;background:#05070a" '
              'title="Finans Kokpiti"></iframe>\'; try{_f.style.padding=\'0\';}catch(e){}')
    bijs = pat.sub(lambda m: IFRAME, bijs, count=1)
    ANCH = 'async function ciz_finans() {'
    if ANCH not in bijs: sys.exit("HATA: bi.js ciz_finans anchor yok")
    bijs = bijs.replace(ANCH, ANCH + "\n    if (!document.getElementById('finans-govde')) return; /* kokpit iframe aktif */", 1)
    print("bi.js: finans odasi -> iframe(/api/bi/kokpit)")

shutil.copy2(S, S+".k2.bak"); shutil.copy2(B, B+".k2.bak")
open(S,"w",encoding="utf-8").write(srv); open(B,"w",encoding="utf-8").write(bijs)
try:
    chk = subprocess.run(["node","--check",S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S+".k2.bak",S); shutil.copy2(B+".k2.bak",B)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n"+chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: host'ta node yok, --check atlandi (yedek: *.k2.bak)")
print("OK: /api/bi/kokpit + iframe hazir. Simdi docker build + compose up.")
