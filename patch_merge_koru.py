#!/usr/bin/env python3
# MERGE_KORU_V1 — alacak_yaslandirma yuklemesini "carileri koru" birlestirmeye cevirir.
#   Dosyadaki cariler (risk) guncellenir; dosyada OLMAYAN cariler KIMLIGIYLE KALIR, riski 0'lanir.
#   Sonuc: bi_musteri_risk tum ~38.765 cariyi korur (kanal/grup DUSMEZ). SAP DEGISMEZ, manuel sorgu YOK.
# Idempotent, assert-korumali. Stage-1 yamali erp_ingest.py UZERINE uygulanir. Baska tipi ETKILEMEZ.
import sys, py_compile, os

FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/erp_ingest.py"
s = open(FP, encoding="utf-8").read()

if "koru_carileri" in s:
    print("zaten yamali (koru_carileri), atlandi"); print("DONE."); raise SystemExit

def rep(old, new, tag):
    assert s.count(old) == 1, "ankor yok/coklu: " + tag + " (n=" + str(s.count(old)) + ")"
    return s.replace(old, new, 1)

# 1) alacak_yaslandirma tipine bayrak ekle (grupla satiri bu tipe OZGU, tek)
old1 = '    "grupla": _yaslandirma_grupla,\n'
new1 = '    "grupla": _yaslandirma_grupla,\n    "koru_carileri": True,\n'
s = rep(old1, new1, "flag")

# 2) yukle(): DELETE'ten ONCE (with blogunun basinda) mevcut carileri belege tasi
BLOK = (
    '            if k.get("koru_carileri"):\n'
    '                # CARILERI KORU: dosyada olmayan cariler kimligiyle kalir, riski 0. Kanal/grup dusmez.\n'
    '                _incoming = {str(r.get("muhatap_kodu", "")) for r in satir}\n'
    '                cur.execute(f"SELECT muhatap_kodu, muhatap_adi, grup, satis_calisani '
    'FROM {k[\'tablo\']} WHERE tenant_id=%s{cast}", (tenant_id,))\n'
    '                _seen = set()\n'
    '                for _kod, _ad, _grup, _sc in cur.fetchall():\n'
    '                    _kk = str(_kod or "")\n'
    '                    if _kk in _incoming or _kk in _seen:\n'
    '                        continue\n'
    '                    _seen.add(_kk)\n'
    '                    _G = (_grup or "").upper()\n'
    '                    satir.append({\n'
    '                        "muhatap_kodu": _kod, "muhatap_adi": _ad or "", "grup": _grup or "",\n'
    '                        "satis_calisani": _sc or "", "hesap_bakiyesi": 0.0, "kredi_limiti": 0.0,\n'
    '                        "toplam_risk": 0.0, "vadesi_gecmis": 0.0, "bekleyen_siparis": 0.0,\n'
    '                        "limit_asimi": 0.0,\n'
    '                        "musteri_mi": ("TEDAR" not in _G) and ("PERSONEL" not in _G),\n'
    '                    })\n'
)
old2 = '    try:\n        with cn, cn.cursor() as cur:\n            if mod == "tarih_araligi" and aralik:'
new2 = '    try:\n        with cn, cn.cursor() as cur:\n' + BLOK + '            if mod == "tarih_araligi" and aralik:'
s = rep(old2, new2, "carryforward")

tmp = FP + ".yeni2"
open(tmp, "w", encoding="utf-8").write(s)
py_compile.compile(tmp, doraise=True)
os.replace(tmp, FP)
print("yamalandi: koru_carileri bayragi + yukle() carry-forward blogu")
print("DONE.")
