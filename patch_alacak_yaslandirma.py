#!/usr/bin/env python3
# ALACAK_YASLANDIRMA_V1 — erp_ingest.py'ye yeni tip + grupla hook ekler.
# SUNUCUDA calisir (varsayilan /opt/krb-assessment/erp_ingest.py). Idempotent, assert-korumali.
# DEDUP/VADESI_CAP blogUNA DOKUNMAZ (yalnizca stabil ankor satirlari). Mevcut tipleri ETKILEMEZ.
import sys, py_compile, tempfile, os

FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/erp_ingest.py"
s = open(FP, encoding="utf-8").read()

if "alacak_yaslandirma" in s or "_yaslandirma_grupla" in s:
    print("zaten yamali, atlandi"); print("DONE."); raise SystemExit

DEFS = '''# ---- ALACAK_YASLANDIRMA_V1: belge bazli alacak yaslandirma -> bi_musteri_risk ----
def gun_onar(v):
    """Vadesi Gecen Gun: tamsayi. Excel bazi hucreleri 1900/1904 tarihine bozuyor (1900-01-09 = 9 gun)."""
    import datetime as _dt
    if v is None or v == "": return None
    if isinstance(v, _dt.datetime): v = v.date()
    if isinstance(v, _dt.date):
        try: return (v - _dt.date(1900, 1, 1)).days + 1
        except Exception: return None
    if isinstance(v, (int, float)): return int(round(v))
    s = str(v).strip()
    if not s or s in ("·", "-"): return None
    for _f in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%d/%m/%Y"):
        try: return (_dt.datetime.strptime(s, _f).date() - _dt.date(1900, 1, 1)).days + 1
        except Exception: pass
    try: return int(float(s.replace(".", "").replace(",", ".")))
    except Exception: return None


def _yaslandirma_grupla(rows):
    """Belge satirlari -> cari basina tek bi_musteri_risk satiri.
       FIFO: en eski fatura once odenir; kalan net bakiye = en guncel faturalar; gun>0 kismi = vadesi gecmis.
       toplam_risk = net bakiye (cek/senet kaynagi yok)."""
    r0 = rows[0]
    bak = float(r0.get("hesap_bakiyesi") or 0.0)
    kl = float(r0.get("kredi_limiti") or 0.0)
    grup = r0.get("grup") or ""
    fill = max(bak, 0.0); acc = 0.0; overdue = 0.0
    for r in sorted(rows, key=lambda x: (x["_gun"] if x.get("_gun") is not None else 0)):
        if acc >= fill: break
        take = min(float(r.get("_acik") or 0.0), fill - acc)
        if take <= 0: continue
        acc += take
        if (r.get("_gun") or -1) > 0: overdue += take
    toplam_risk = max(bak, 0.0)
    G = grup.upper()
    return {
        "muhatap_kodu": r0["muhatap_kodu"], "muhatap_adi": r0.get("muhatap_adi", ""),
        "grup": grup, "satis_calisani": r0.get("satis_calisani", ""),
        "hesap_bakiyesi": bak, "kredi_limiti": kl, "toplam_risk": toplam_risk,
        "vadesi_gecmis": round(overdue, 2), "bekleyen_siparis": 0.0,
        "limit_asimi": max(0.0, toplam_risk - kl),
        "musteri_mi": ("TEDAR" not in G) and ("PERSONEL" not in G),
    }


'''

TYPE = '''  "alacak_yaslandirma": {
    "ad": "Belge bazli alacak yaslandirma (yeni cari risk kaynagi)",
    "imza": ["Customer/Vendor Code", "Açık Tutar", "Vadesi Geçen Gün", "Document Total"],
    "tablo": "bi_musteri_risk",
    "dogal_anahtar": ["muhatap_kodu"],
    "grupla": _yaslandirma_grupla,
    "tenant_tip": "uuid",
    "yukleme_modu": "tam_degistir",
    "kolonlar": {
      "muhatap_kodu"   : (None, "Customer/Vendor Code", "metin"),
      "muhatap_adi"    : (None, "Customer/Vendor Name", "metin"),
      "grup"           : (None, "Group Name", "metin"),
      "satis_calisani" : (None, "Sales Employee Name", "metin"),
      "hesap_bakiyesi" : (None, "Account Balance", "sayi2"),
      "kredi_limiti"   : (None, "Kredi Limiti", "sayi2"),
      "_acik"          : (None, "Açık Tutar", "sayi4"),
      "_gun"           : (None, "Vadesi Geçen Gün", "gun"),
    },
    "cikti_alanlar": ["muhatap_kodu", "muhatap_adi", "grup", "satis_calisani", "hesap_bakiyesi",
                      "kredi_limiti", "toplam_risk", "vadesi_gecmis", "bekleyen_siparis", "limit_asimi", "musteri_mi"],
    "kapilar": [
      ("bos_kod", lambda R: sum(1 for r in R if not r["muhatap_kodu"]), 10, "Customer/Vendor Code bos"),
      ("gecikmis_riski_asiyor", lambda R: sum(1 for r in R if r["toplam_risk"] > 0 and r["vadesi_gecmis"] > r["toplam_risk"] * 1.05),
       200, "vadesi gecmis > toplam risk"),
    ],
  },

'''

def rep(old, new, etiket):
    assert s.count(old) == 1, "ankor bulunamadi/coklu: " + etiket + " (n=" + str(s.count(old)) + ")"
    return s.replace(old, new, 1)

# 1) oku(): "gun" tur brasi (sayi'dan ONCE)
old1 = '            elif tur.startswith("sayi"):'
new1 = '            elif tur == "gun":\n                d[alan] = gun_onar(v)\n            elif tur.startswith("sayi"):'
s = rep(old1, new1, "oku-gun")

# 2) oku() sonu: grupla (belge -> cari)
old2 = '        satir.append(d)\n    wb.close()\n    return tip, satir, istat'
new2 = ('        satir.append(d)\n    wb.close()\n'
        '    if k.get("grupla"):\n'
        '        _grp = {}\n'
        '        for _r in satir:\n'
        '            _gk = tuple(str(_r.get(_a, "")) for _a in k["dogal_anahtar"])\n'
        '            _grp.setdefault(_gk, []).append(_r)\n'
        '        satir = [k["grupla"](_rows) for _rows in _grp.values()]\n'
        '    return tip, satir, istat')
s = rep(old2, new2, "oku-grupla")

# 3) DEFS (gun_onar + _yaslandirma_grupla) + yeni tip: KAYIT girisinde
old3 = 'KAYIT = {\n\n  "stok_hareket": {'
new3 = DEFS + '\nKAYIT = {\n\n' + TYPE + '  "stok_hareket": {'
s = rep(old3, new3, "KAYIT+DEFS+TYPE")

# 4) yukle(): grupla tipinde INSERT sutunlari cikti_alanlar'dan
old4 = '    alanlar = list(k["kolonlar"].keys()) + list((k.get("turet") or {}).keys())'
new4 = '    alanlar = list(k["cikti_alanlar"]) if k.get("cikti_alanlar") else (list(k["kolonlar"].keys()) + list((k.get("turet") or {}).keys()))'
s = rep(old4, new4, "alanlar-cikti")

# yaz + sozdizim
tmp = FP + ".yeni"
open(tmp, "w", encoding="utf-8").write(s)
py_compile.compile(tmp, doraise=True)
os.replace(tmp, FP)
print("yamalandi: gun tipi + grupla + alacak_yaslandirma tipi + cikti_alanlar")
print("DONE.")
