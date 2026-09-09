#!/usr/bin/env python3
# MUSTERIMI_GRUP_V1 — musteri_mi artık yalnız kod öneki 'M' DEĞİL; grup 'TEDARİKÇİ' ise MÜŞTERİ SAYILMAZ.
# Sebep: OTOMOTİV LASTİKLERİ TEVZİ (Continental) kod M ama grup TEDARİKÇİ → phantom 35M gecikmiş.
# Bu tek değişiklik tüm downstream'i düzeltir (musteri_mi ile filtreleyen tüm risk/DSO/master sorguları).
# grup satırda mevcut (KAYIT map, "Grup"). Idempotent. /opt/krb-assessment. REBUILD gerekir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "erp_ingest.py"
s = read(FP)
if "MUSTERIMI_GRUP_V1" in s:
    print("musterimi: already present, skip"); print("DONE."); raise SystemExit

a = '      "musteri_mi" : lambda r: r["muhatap_kodu"].upper().startswith("M"),'
n = ('      # MUSTERIMI_GRUP_V1 — kod öneki M + grup TEDARİKÇİ değil (tedarikçi müşteri sayılmaz).\n'
     '      "musteri_mi" : lambda r: r["muhatap_kodu"].upper().startswith("M") and "TEDAR" not in (r.get("grup") or "").upper(),')
assert s.count(a) == 1, "musteri_mi anchor"
s = s.replace(a, n, 1)

write(FP, s)
print("musterimi: musteri_mi artık TEDARİKÇİ grubunu hariç tutuyor")
print("DONE.")
