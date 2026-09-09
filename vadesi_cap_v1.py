#!/usr/bin/env python3
# VADESI_CAP_V1 — erp_ingest DEDUP_V2 duzeltmesi.
#   KOK NEDEN: CARI RISK raporu her musteriyi "Ödeme Biçimi"ne (Havale/Çek/Kredi Kartı/Peşin) gore satira boler.
#     "Vadesi Geçmiş Bakiye" bu satirlarda KUMULATIF/kanal-bazli — bir satir musterinin TUM toplam_risk'ini asabiliyor
#     (ROTA: Havale satiri 19.867.055 iken toplam_risk 3.958.335). Bu ANLIK gecikmis DEGIL.
#   Eski dedup: dedup_max = plain MAX -> imkansiz kanal degerini secip 616 musteride ~981M hayalet gecikmis uretti.
#   COZUM: vadesi_gecmis icin toplam_risk'i asan satirlari YOK SAY, kalanlarin MAX'ini al.
#     Sirket geneli gecikmis 787M -> 225.7M (bakiye 228M ile tutarli). ROTA 19.9M -> 172.8K.
#   bekleyen_siparis eski davranista (plain MAX) kalir. Yukleme sonrasi RE-INGEST gerekir (DB'yi tazelemek icin).
# /opt/krb-assessment/erp_ingest.py (imaja build'de gomulur -> docker build + up + yeniden yukle). Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "erp_ingest.py"
s = read(FP)
if "VADESI_CAP_V1" in s:
    print("vadesi-cap: already present, skip"); print("DONE."); raise SystemExit

A = '''    dedup_dusen = 0
    if mod == "tam_degistir" and k.get("dogal_anahtar"):
        _da = k["dogal_anahtar"]
        _mx = k.get("dedup_max") or []
        _u = {}
        for _r in satir:
            _key = tuple(str(_r.get(_a, "")) for _a in _da)
            if _key not in _u:
                _u[_key] = dict(_r)
            else:
                _b = _u[_key]
                for _f in _mx:
                    try:
                        if float(_r.get(_f) or 0) > float(_b.get(_f) or 0):
                            _b[_f] = _r.get(_f)
                    except Exception:
                        pass
        dedup_dusen = len(satir) - len(_u)
        satir = list(_u.values())
'''
assert s.count(A) == 1, "DEDUP_V2 block anchor (count=%d)" % s.count(A)

N = '''    dedup_dusen = 0
    if mod == "tam_degistir" and k.get("dogal_anahtar"):
        _da = k["dogal_anahtar"]
        _mx = k.get("dedup_max") or []
        _u = {}
        for _r in satir:
            _key = tuple(str(_r.get(_a, "")) for _a in _da)
            if _key not in _u:
                _b = dict(_r)
                for _f in _mx:
                    _b[_f] = 0.0
                _u[_key] = _b
            _b = _u[_key]
            for _f in _mx:
                try:
                    _cand = float(_r.get(_f) or 0)
                except Exception:
                    continue
                # VADESI_CAP_V1 — CARI RISK "Vadesi Geçmiş Bakiye" Ödeme Biçimi'ne göre çoğalıyor; bazı satırlar
                #   KÜMÜLATİF (toplam riski aşan) → gerçek anlık gecikmiş DEĞİL. Aşan satırları at, kalanların MAX'ı.
                if _f == "vadesi_gecmis":
                    try:
                        _tr = float(_b.get("toplam_risk") or 0)
                    except Exception:
                        _tr = 0.0
                    if _tr > 0 and _cand > _tr:
                        continue
                if _cand > float(_b.get(_f) or 0):
                    _b[_f] = _r.get(_f)
        dedup_dusen = len(satir) - len(_u)
        satir = list(_u.values())
'''
s = s.replace(A, N, 1)
write(FP, s)
print("vadesi-cap: DEDUP_V2 -> capped-MAX (vadesi_gecmis toplam_risk'i asan satirlar atilir)")
print("marker:", s.count("VADESI_CAP_V1"))
print("DONE.")
