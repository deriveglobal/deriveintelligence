#!/usr/bin/env python3
# MUSTERI_ARA_TR_NORMALIZE_V1 (server) — Ali Kemal 04.08: "kucuk harf ile yazilmis musteri
#   kartlarina yeni aktivite olustururken bulmuyor, bu carilere aktivite giremiyorum".
#   Kok-neden: GET /api/saha/musteri-ara `firma ILIKE '%q%'` kullaniyor. ILIKE ASCII'de
#   buyuk/kucuk duyarsiz ama TURKCE harflerde (İ/ı, ş, ç, ö, ü, ğ) Postgres harf-katlamasi
#   Turkce-uyumlu degil → kucuk harfle (ozellikle dotless ı / dotted i) yazilmis firma adlari
#   farkli case ile aranınca eslesmiyor.
#   Fix: eslestirmeyi TR-normalize et: lower(translate(X,'İIıŞşÇçÖöÜüĞğ','iiissccoouugg')).
#   Hem firma (saha_musteri) hem musteri_adi (master_musteri) hem ORDER BY prefix. Vergi_no exact
#   kalir. Normalize edilmis LIKE, ILIKE eslesmelerinin ust-kumesidir → yalniz sonuc EKLER, cikarmaz.
#   Idempotent (marker: MUSTERI_ARA_TR_NORMALIZE_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_ARA_TR_NORMALIZE_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# sanity: translate map uzunluklari esit olmali
_FROM = "İIıŞşÇçÖöÜüĞğ"
_TO   = "iiissccoouugg"
assert len(_FROM) == len(_TO), f"translate map uzunluk uyusmazligi: {len(_FROM)} vs {len(_TO)}"

# 1) _nrm helper + condK
old1 = '''      const isRep = session.sahaRole === "rep";  /* MUSTERI_ARA_REP_SCOPE_V1 — rep yalniz kendi musterileri (sorumlu_rep) */
      const paramsK = [session.tenantId, like, prefix];
      let condK = "firma ILIKE $2";'''
new1 = '''      const isRep = session.sahaRole === "rep";  /* MUSTERI_ARA_REP_SCOPE_V1 — rep yalniz kendi musterileri (sorumlu_rep) */
      const _nrm = (x) => `lower(translate(${x},'İIıŞşÇçÖöÜüĞğ','iiissccoouugg'))`;  /* ''' + MARK + ''' — TR harf + buyuk/kucuk duyarsiz */
      const paramsK = [session.tenantId, like, prefix];
      let condK = `${_nrm("firma")} LIKE ${_nrm("$2")}`;'''
if old1 not in src:
    print("HATA: condK/isRep anchor bulunamadi"); sys.exit(1)
src = src.replace(old1, new1, 1)
print("[+] _nrm helper + condK normalize")

# 2) SAHA order by
old2 = '''        ORDER BY (firma ILIKE $3) DESC, firma'''
new2 = '''        ORDER BY (${_nrm("firma")} LIKE ${_nrm("$3")}) DESC, firma'''
if old2 not in src:
    print("HATA: SAHA ORDER BY anchor bulunamadi"); sys.exit(1)
src = src.replace(old2, new2, 1)
print("[+] SAHA ORDER BY normalize")

# 3) ERP where
old3 = '''        WHERE tenant_id = $1 AND musteri_adi ILIKE $2'''
new3 = '''        WHERE tenant_id = $1 AND ${_nrm("musteri_adi")} LIKE ${_nrm("$2")}'''
if old3 not in src:
    print("HATA: ERP WHERE anchor bulunamadi"); sys.exit(1)
src = src.replace(old3, new3, 1)
print("[+] ERP WHERE normalize")

# 4) ERP order by
old4 = '''        ORDER BY (musteri_adi ILIKE $3) DESC, toplam_ciro DESC NULLS LAST'''
new4 = '''        ORDER BY (${_nrm("musteri_adi")} LIKE ${_nrm("$3")}) DESC, toplam_ciro DESC NULLS LAST'''
if old4 not in src:
    print("HATA: ERP ORDER BY anchor bulunamadi"); sys.exit(1)
src = src.replace(old4, new4, 1)
print("[+] ERP ORDER BY normalize")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
