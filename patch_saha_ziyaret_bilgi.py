#!/usr/bin/env python3
# saha_fix_7 (omurga_78) — Ziyaret Kaydet formunda müşteri kimlik/iletişim bilgisi salt-okunur gösterilir (Eftal talebi).
# Sunucu: musteri-ara SAHA sonuclarina yetkili/telefon/vergi_no/tc_no eklenir (arama ile acilan ziyaret formu da bilgiyi tasisin).
# Frontend strip saha.js'te. Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

OLD = """      const kart = await query(`
        SELECT id, tip, firma, musteri_kodu, il, ilce, segment, durum
        FROM saha_musteri
        WHERE tenant_id = $1 AND aktif = true AND (firma ILIKE $2"""
NEW = """      const kart = await query(`
        SELECT id, tip, firma, musteri_kodu, il, ilce, segment, durum, yetkili, telefon, vergi_no, tc_no
        FROM saha_musteri
        WHERE tenant_id = $1 AND aktif = true AND (firma ILIKE $2"""

if "segment, durum, yetkili, telefon, vergi_no, tc_no" in srv:
    sys.exit("ZATEN VAR: saha_fix_7 uygulanmis gibi.")
if OLD not in srv:
    sys.exit("HATA: musteri-ara SAHA SELECT bulunamadi (elle bak).")
if srv.count(OLD) != 1:
    sys.exit("UYARI: anchor %d kez — belirsiz." % srv.count(OLD))
srv = srv.replace(OLD, NEW, 1)

shutil.copy2(S, S + ".zbilgi.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".zbilgi.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .zbilgi.bak)")
print("OK: musteri-ara SAHA sonuclari kimlik/iletisim tasiyor. saha.js -> shells/, sonra build.")
