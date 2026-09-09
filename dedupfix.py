#!/usr/bin/env python3
# DEDUP_V1 — tam-değiştir (snapshot) yüklemelerinde doğal anahtara göre tekilleştir.
# Sebep: CARI RISK raporu aynı müşteriyi ödeme biçimi vb. yüzünden çoğaltıyor (48601 satır /
# 38765 müşteri). Risk sayıları müşteri başına AYNI; unique constraint tek satır bekliyor ->
# UniqueViolation. Çözüm: yalnız tam_değiştir + doğal_anahtar tanımlı tiplerde, INSERT öncesi
# anahtar bazında tekilleştir (son satır kazanır). Yalnız musteri_risk etkilenir (tek dogal_anahtar
# eklenen tam_değiştir tipi). Zaman-serisi tipleri (satis/tedarikci/stok_hareket) mod!=tam_degistir
# olduğu için DOKUNULMAZ. Idempotent. /opt/krb-assessment içinde çalıştır. REBUILD gerekir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "erp_ingest.py"
s = read(FP)
if "DEDUP_V1" in s:
    print("dedup: already present, skip"); print("DONE."); raise SystemExit

# (1) musteri_risk'e dogal_anahtar ekle
a1 = '    "tablo": "bi_musteri_risk",\n    "tenant_tip": "uuid",'
n1 = '    "tablo": "bi_musteri_risk",\n    "dogal_anahtar": ["muhatap_kodu"],\n    "tenant_tip": "uuid",'
assert s.count(a1) == 1, "musteri_risk anchor"
s = s.replace(a1, n1, 1)

# (2) yukle(): INSERT öncesi dedup bloğu
a2 = ('    alanlar = list(k["kolonlar"].keys()) + list((k.get("turet") or {}).keys())\n'
      '    cast = "::uuid" if k["tenant_tip"] == "uuid" else ""')
n2 = ('    # DEDUP_V1 — tam-değiştir snapshot: doğal anahtara göre tekilleştir (son satır kazanır).\n'
      '    dedup_dusen = 0\n'
      '    if mod == "tam_degistir" and k.get("dogal_anahtar"):\n'
      '        _da = k["dogal_anahtar"]\n'
      '        _u = {}\n'
      '        for _r in satir:\n'
      '            _u[tuple(str(_r.get(_a, "")) for _a in _da)] = _r\n'
      '        dedup_dusen = len(satir) - len(_u)\n'
      '        satir = list(_u.values())\n'
      '\n'
      '    alanlar = list(k["kolonlar"].keys()) + list((k.get("turet") or {}).keys())\n'
      '    cast = "::uuid" if k["tenant_tip"] == "uuid" else ""')
assert s.count(a2) == 1, "insert-region anchor"
s = s.replace(a2, n2, 1)

# (3) başarı dönüşüne tekillestirilen ekle
a3 = '    return {"ok": True, "tip": tip, "ad": k["ad"], "satir": len(satir),'
n3 = '    return {"ok": True, "tip": tip, "ad": k["ad"], "satir": len(satir),\n            "tekillestirilen": dedup_dusen,'
assert s.count(a3) == 1, "success-return anchor"
s = s.replace(a3, n3, 1)

write(FP, s)
print("dedup: musteri_risk dogal_anahtar + dedup block + report field patched")
print("DONE.")
