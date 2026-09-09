#!/usr/bin/env python3
# TAHSILAT_V1 — erp_ingest.py'ye tahsilat tipi + _tahsilat_grupla ekler (7. dosya -> bi_tahsilat).
#   Faz 1 makinesini (gun tipi, grupla hook, cikti_alanlar) YENIDEN kullanir. Mevcut tipleri ETKILEMEZ.
# Idempotent, assert-korumali. Sunucuda /opt/krb-assessment/erp_ingest.py uzerine.
import sys, py_compile, os

FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/erp_ingest.py"
s = open(FP, encoding="utf-8").read()

if '"tahsilat"' in s or "_tahsilat_grupla" in s:
    print("zaten yamali (tahsilat), atlandi"); print("DONE."); raise SystemExit

def rep(old, new, tag):
    assert s.count(old) == 1, "ankor yok/coklu: " + tag + " (n=" + str(s.count(old)) + ")"
    return s.replace(old, new, 1)

DEFS = '''# ---- TAHSILAT_V1: tahsilat durumu (odeme davranisi / gercek DSO) -> bi_tahsilat ----
def _tahsilat_grupla(rows):
    """Fatura<->tahsilat satirlari -> cari basina tek bi_tahsilat satiri.
       Tam gecmis + son 12 ay pencereleri; tutar-agirlikli sure/gecikme; gun kolonu bossa tarihlerden turetir."""
    import datetime as _dt
    def _ad(x):
        if x is None or x == "": return None
        if isinstance(x, _dt.datetime): return x.date()
        if isinstance(x, _dt.date): return x
        _s = str(x)[:10]
        try: return _dt.datetime.strptime(_s, "%Y-%m-%d").date()
        except Exception:
            for _f in ("%d/%m/%Y", "%d.%m.%Y"):
                try: return _dt.datetime.strptime(str(x).strip(), _f).date()
                except Exception: pass
        return None
    today = _dt.date.today(); cut12 = today - _dt.timedelta(days=365)
    r0 = rows[0]; grup = r0.get("grup") or ""
    tot = 0.0; ws = 0.0; wv = 0.0; late = 0.0; adet = 0
    r_t = 0.0; r_ws = 0.0; r_wv = 0.0; r_late = 0.0; r_adet = 0; son = None
    for r in rows:
        od = float(r.get("_od") or 0.0)
        sv = r.get("_sure"); vv = r.get("_vg")
        fd = _ad(r.get("_fd")); vd = _ad(r.get("_vd")); td = _ad(r.get("_td"))
        if sv is None and fd and td: sv = (td - fd).days
        if vv is None and vd and td: vv = (td - vd).days
        adet += 1; tot += od
        if sv is not None: ws += sv * od
        if vv is not None:
            wv += vv * od
            if vv > 0: late += od
        if td and (son is None or td > son): son = td
        if td and td >= cut12:
            r_adet += 1; r_t += od
            if sv is not None: r_ws += sv * od
            if vv is not None:
                r_wv += vv * od
                if vv > 0: r_late += od
    _dv = lambda w, t: round(w / t, 2) if t > 0 else 0.0
    G = grup.upper()
    return {
        "muhatap_kodu": r0["muhatap_kodu"], "muhatap_adi": r0.get("muhatap_adi", ""),
        "grup": grup, "satis_calisani": r0.get("satis_calisani", ""),
        "tahsilat_adedi": adet, "toplam_tahsilat": round(tot, 2),
        "ort_tahsilat_suresi": _dv(ws, tot), "ort_gecikme_gun": _dv(wv, tot),
        "gec_odeme_orani": round(100 * late / tot, 2) if tot > 0 else 0.0,
        "son12_adedi": r_adet, "son12_tutar": round(r_t, 2),
        "son12_suresi": _dv(r_ws, r_t), "son12_gecikme_gun": _dv(r_wv, r_t),
        "son12_gec_orani": round(100 * r_late / r_t, 2) if r_t > 0 else 0.0,
        "son_tahsilat_tarihi": son,
        "musteri_mi": ("TEDAR" not in G) and ("PERSONEL" not in G),
    }


'''

TYPE = '''  "tahsilat": {
    "ad": "Tahsilat durumu (odeme davranisi / gercek DSO)",
    "imza": ["Ödenen Tutar", "Tahsilat Süresi", "Tahsilat türü", "Fatura Vade Tarihi"],
    "tablo": "bi_tahsilat",
    "dogal_anahtar": ["muhatap_kodu"],
    "grupla": _tahsilat_grupla,
    "tenant_tip": "uuid",
    "yukleme_modu": "tam_degistir",
    "kolonlar": {
      "muhatap_kodu"   : (None, "Customer/Vendor Code", "metin"),
      "muhatap_adi"    : (None, "Customer/Vendor Name", "metin"),
      "grup"           : (None, "Group Name", "metin"),
      "satis_calisani" : (None, "Sales Employee Name", "metin"),
      "_od"            : (None, "Ödenen Tutar", "sayi2"),
      "_sure"          : (None, "Tahsilat Süresi", "gun"),
      "_vg"            : (None, "Vadesi Geçen Gün", "gun"),
      "_fd"            : (None, "Fatura Tarihi", "tarih"),
      "_vd"            : (None, "Fatura Vade Tarihi", "tarih"),
      "_td"            : (None, "Tahsilat Tarihi", "tarih"),
    },
    "cikti_alanlar": ["muhatap_kodu", "muhatap_adi", "grup", "satis_calisani", "tahsilat_adedi",
                      "toplam_tahsilat", "ort_tahsilat_suresi", "ort_gecikme_gun", "gec_odeme_orani",
                      "son12_adedi", "son12_tutar", "son12_suresi", "son12_gecikme_gun",
                      "son12_gec_orani", "son_tahsilat_tarihi", "musteri_mi"],
    "kapilar": [
      ("bos_kod", lambda R: sum(1 for r in R if not r["muhatap_kodu"]), 10, "Customer/Vendor Code bos"),
      ("gec_orani_bozuk", lambda R: sum(1 for r in R if r["gec_odeme_orani"] < 0 or r["gec_odeme_orani"] > 100.5),
       0, "gec_odeme_orani 0-100 disinda"),
    ],
  },

'''

old = 'KAYIT = {\n\n  "alacak_yaslandirma": {'
new = DEFS + 'KAYIT = {\n\n' + TYPE + '  "alacak_yaslandirma": {'
s = rep(old, new, "tahsilat DEFS+TYPE")

tmp = FP + ".yeni3"
open(tmp, "w", encoding="utf-8").write(s)
py_compile.compile(tmp, doraise=True)
os.replace(tmp, FP)
print("yamalandi: _tahsilat_grupla + tahsilat tipi (bi_tahsilat)")
print("DONE.")
