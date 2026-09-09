#!/usr/bin/env python3
# saha_fix_6 (omurga_78) — Yeni musteri/ziyaret: ERP carisinin TC KIMLIK NO'sunu da otomatik doldur (VKN gibi).
# Rep raporu (Eftal): mevcut musteride vkn/tc/yetkili/telefon elle giriliyor.
# ERP master'da vergi_no + tc_no VAR -> otomatik. telefon/yetkili ERP'de YOK -> elle kalir.
# patch_saha_vkn.py (fix_2) uzerine gelir. SADECE server; saha.js ayrica.
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

E = [
("SELECT musteri_kodu, musteri_adi, son_fatura, fatura_sayisi, toplam_ciro, vergi_no\n        FROM master_musteri",
 "SELECT musteri_kodu, musteri_adi, son_fatura, fatura_sayisi, toplam_ciro, vergi_no, tc_no\n        FROM master_musteri"),
('kaynak: "ERP", firma: r.musteri_adi, musteri_kodu: r.musteri_kodu, vergi_no: r.vergi_no,\n            son_fatura: r.son_fatura',
 'kaynak: "ERP", firma: r.musteri_adi, musteri_kodu: r.musteri_kodu, vergi_no: r.vergi_no, tc_no: r.tc_no,\n            son_fatura: r.son_fatura'),
]

if "tc_no: r.tc_no" in srv:
    sys.exit("ZATEN VAR: saha_fix_6 uygulanmis gibi.")
if "vergi_no: r.vergi_no" not in srv:
    sys.exit("DUR: once VKN (patch_saha_vkn.py / fix_2) uygulanmali.")
for i, (o, n) in enumerate(E, 1):
    if o not in srv:
        sys.exit("HATA: %d. blok bulunamadi (elle bak)." % i)
    if srv.count(o) != 1:
        sys.exit("UYARI: %d. blok %d kez — belirsiz." % (i, srv.count(o)))
    srv = srv.replace(o, n, 1)

shutil.copy2(S, S + ".tc.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".tc.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .tc.bak)")
print("OK: musteri-ara ERP tc_no donuyor -> TC autofill. saha.js -> shells/, sonra build.")
