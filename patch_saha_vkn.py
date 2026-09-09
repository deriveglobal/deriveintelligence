#!/usr/bin/env python3
# saha_fix_2 (omurga_78) — VKN autofill: musteri-ara ERP carisinin vergi_no'sunu doner ->
# yeni musteri formunda VKN otomatik dolar (rep raporu: mevcut musteride bilgileri elle giriyoruz).
# NOT: master_musteri'de telefon/il/yetkili yok -> sadece VKN otomatik; digerleri elle kalir.
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

OLD1 = "SELECT musteri_kodu, musteri_adi, son_fatura, fatura_sayisi, toplam_ciro\n        FROM master_musteri"
NEW1 = "SELECT musteri_kodu, musteri_adi, son_fatura, fatura_sayisi, toplam_ciro, vergi_no\n        FROM master_musteri"
OLD2 = 'kaynak: "ERP", firma: r.musteri_adi, musteri_kodu: r.musteri_kodu,\n            son_fatura: r.son_fatura'
NEW2 = 'kaynak: "ERP", firma: r.musteri_adi, musteri_kodu: r.musteri_kodu, vergi_no: r.vergi_no,\n            son_fatura: r.son_fatura'

if "vergi_no: r.vergi_no" in srv:
    sys.exit("ZATEN VAR: saha_fix_2 uygulanmis gibi.")
for i, (o, n) in enumerate([(OLD1, NEW1), (OLD2, NEW2)], 1):
    if o not in srv:
        sys.exit("HATA: %d. anchor bulunamadi (elle bak)." % i)
    if srv.count(o) != 1:
        sys.exit("UYARI: %d. anchor %d kez — belirsiz." % (i, srv.count(o)))
    srv = srv.replace(o, n, 1)

shutil.copy2(S, S + ".sahavkn.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".sahavkn.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .sahavkn.bak)")
print("OK: musteri-ara ERP vergi_no donuyor -> VKN autofill. saha.js -> shells/, sonra build.")
