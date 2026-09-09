#!/usr/bin/env python3
# DEDUP_V2 — DEDUP_V1'i (son satır kazanır) DÜZELTİR. Sorun: CARI RISK ödeme biçimine göre
# çoğalıyor; vadesi_gecmis/bekleyen_siparis tek satırda dolu, diğer satırlarda 0. "Son kazanır"
# çoğu kez 0'lı satırı tutup gecikmiş alacağı kaybediyordu → kokpitte riskli müşteri yok, DSO düşük.
# Çözüm: sabit alanlar ilk satırdan; fan-out alanları (dedup_max) müşteri satırları boyunca MAX alınır
# (muhafazakâr: riskli fazla göstermez). SUM istenirse max(...)->toplam yapılır. Idempotent. REBUILD.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "erp_ingest.py"
s = read(FP)
if "DEDUP_V2" in s:
    print("dedup2: already present, skip"); print("DONE."); raise SystemExit
if "DEDUP_V1" not in s:
    print("WARN: DEDUP_V1 yok — önce dedupfix.py"); raise SystemExit

# (1) musteri_risk'e dedup_max ekle
a1 = '    "dogal_anahtar": ["muhatap_kodu"],'
n1 = '    "dogal_anahtar": ["muhatap_kodu"],\n    "dedup_max": ["vadesi_gecmis", "bekleyen_siparis"],'
assert s.count(a1) == 1, "dogal_anahtar anchor"
s = s.replace(a1, n1, 1)

# (2) DEDUP_V1 bloğunu DEDUP_V2 (MAX alan) ile değiştir
a2 = ('    # DEDUP_V1 — tam-değiştir snapshot: doğal anahtara göre tekilleştir (son satır kazanır).\n'
      '    dedup_dusen = 0\n'
      '    if mod == "tam_degistir" and k.get("dogal_anahtar"):\n'
      '        _da = k["dogal_anahtar"]\n'
      '        _u = {}\n'
      '        for _r in satir:\n'
      '            _u[tuple(str(_r.get(_a, "")) for _a in _da)] = _r\n'
      '        dedup_dusen = len(satir) - len(_u)\n'
      '        satir = list(_u.values())')
n2 = ('    # DEDUP_V2 — tam-değiştir snapshot: sabit alanlar ilk satırdan; fan-out alanları\n'
      '    #   (dedup_max) müşteri satırları boyunca MAX. CARI RISK ödeme biçimine göre çoğalıyor:\n'
      '    #   gecikmiş/bekleyen tek satırda dolu, diğerleri 0 → müşterinin gerçek değerini korur.\n'
      '    dedup_dusen = 0\n'
      '    if mod == "tam_degistir" and k.get("dogal_anahtar"):\n'
      '        _da = k["dogal_anahtar"]\n'
      '        _mx = k.get("dedup_max") or []\n'
      '        _u = {}\n'
      '        for _r in satir:\n'
      '            _key = tuple(str(_r.get(_a, "")) for _a in _da)\n'
      '            if _key not in _u:\n'
      '                _u[_key] = dict(_r)\n'
      '            else:\n'
      '                _b = _u[_key]\n'
      '                for _f in _mx:\n'
      '                    try:\n'
      '                        if float(_r.get(_f) or 0) > float(_b.get(_f) or 0):\n'
      '                            _b[_f] = _r.get(_f)\n'
      '                    except Exception:\n'
      '                        pass\n'
      '        dedup_dusen = len(satir) - len(_u)\n'
      '        satir = list(_u.values())')
assert s.count(a2) == 1, "DEDUP_V1 block anchor"
s = s.replace(a2, n2, 1)

write(FP, s)
print("dedup2: DEDUP_V1 -> DEDUP_V2 (MAX) + dedup_max eklendi")
print("DONE.")
