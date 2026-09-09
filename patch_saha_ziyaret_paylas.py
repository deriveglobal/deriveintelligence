#!/usr/bin/env python3
# saha_fix_4b (omurga_78, ② DUZELTME) — DOGRU model: musteri ziyaret gecmisi HERKESE acik.
# Fatih: "everyone should be able to see all visits to the customer".
# Bir musteri secildiginde (musteri_id) ziyaret listesi rep-filtresi UYGULANMAZ -> tum replerin
# ziyaretleri gorunur (her ziyaret zaten rep adiyla etiketli). Kisisel is listesi (musteri_id yok) rep-scoped kalir.
# NOT: onceki yanlis yon (patch_saha_crossrep.py = son_ziyaret rep-scoped) GERI ALINMALI:
#   server'da:  cp server_container.mjs.crossrep.bak server_container.mjs   (crossrep'i geri al)
#   sonra bu patch calisir (temiz ziyaretler kodu uzerine).
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

if "CROSS_REP_V1" in srv:
    sys.exit("DUR: crossrep hala uygulanmis. ONCE geri al:\n"
             "  cp /opt/krb-assessment/server_container.mjs.crossrep.bak /opt/krb-assessment/server_container.mjs\n"
             "sonra bu patch'i tekrar calistir.")

OLD = '''      if (session.sahaRole === "rep") {
        params.push(session.userId);
        sql += ` AND z.rep_id = $${params.length}`;
      } else if (url.searchParams.get("rep_id")) {'''
NEW = '''      // ZIYARET_PAYLAS_V1 — musteri secilince (musteri_id) ziyaret gecmisi HERKESE acik (rep-filtresi yok).
      //   Kisisel is listesi (musteri_id yok) rep-scoped kalir. Her ziyaret rep adiyla etiketli.
      const _mid = url.searchParams.get("musteri_id");
      if (session.sahaRole === "rep" && !_mid) {
        params.push(session.userId);
        sql += ` AND z.rep_id = $${params.length}`;
      } else if (url.searchParams.get("rep_id")) {'''

if "ZIYARET_PAYLAS_V1" in srv:
    sys.exit("ZATEN VAR: saha_fix_4b uygulanmis gibi.")
if OLD not in srv:
    sys.exit("HATA: ziyaretler rep-filtre blogu bulunamadi (elle bak).")
if srv.count(OLD) != 1:
    sys.exit("UYARI: anchor %d kez — belirsiz." % srv.count(OLD))
srv = srv.replace(OLD, NEW, 1)

shutil.copy2(S, S + ".zpaylas.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".zpaylas.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .zpaylas.bak)")
print("OK: musteri ziyaret gecmisi tum replere acik (rep adiyla). SADECE server — build yeterli.")
