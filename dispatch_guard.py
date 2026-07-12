#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DISPATCH_GUARD_V1 — saha.js view dispatcher'inin cagirdigi HER fonksiyon
UST SEVIYEDE (kolon 0) tanimli mi?

NEDEN: vRakip'i RAPOR modulunun IC closure'ina koydum. Sonuc:
  • node --check      -> GECTI (sozdizimi dogru)
  • guard_shell.sh    -> GECTI (boyut, fonksiyon sayisi, semboller tamam)
  • GERCEK TARAYICI   -> "Can't find variable: vRakip" -> KABUK HIC ACILMADI
  • TUM TEMSILCILER UYGULAMAYA GIREMEDI.

Iki kapi da "dosya saglam" dedi; hicbiri "uygulama aciliyor mu" demedi.
Bu guard tam olarak o boslugu kapatir.
"""
import re, sys

fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
src = open(fn, encoding="utf-8").read()

# 1) dispatch haritasini bul:  return ({ bugun: vBugun, ... }[v] || vBugun)();
m = re.search(r'return\s*\(\{([^}]+)\}\[v\]\s*\|\|\s*(\w+)\)', src)
if not m:
    print("DISPATCH_GUARD: dispatch haritasi bulunamadi — atlaniyor")
    sys.exit(0)

harita, fallback = m.group(1), m.group(2)
fns = set(re.findall(r':\s*(\w+)', harita)) | {fallback}

# 2) her biri KOLON 0'da tanimli mi?
ust_seviye = set(re.findall(r'^(?:async\s+)?function\s+(\w+)', src, re.M))
ust_seviye |= set(re.findall(r'^(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s*)?\(', src, re.M))

eksik  = sorted(f for f in fns if f not in ust_seviye)
if not eksik:
    print("DISPATCH_GUARD_OK: %d view fonksiyonunun tamami ust seviyede." % len(fns))
    sys.exit(0)

print("=" * 70)
print("DISPATCH_GUARD ✗ — DEPLOY ENGELLENDI")
print("=" * 70)
for f in eksik:
    # nerede tanimli, kac bosluk girintiyle?
    m2 = re.search(r'^(\s+)(?:async\s+)?function\s+' + re.escape(f) + r'\b', src, re.M)
    if m2:
        satir = src[:m2.start()].count("\n") + 1
        print("  ✗ %-14s satir %-6d — %d bosluk GIRINTILI (ic closure!)"
              % (f, satir, len(m2.group(1))))
        print("      Dispatch bu fonksiyonu GOREMEZ. Tarayicida:")
        print("      \"Can't find variable: %s\" -> KABUK ACILMAZ." % f)
    else:
        print("  ✗ %-14s HIC TANIMLI DEGIL" % f)
print()
print("  Cozum: fonksiyonu KOLON 0'a tasi (ornek: 'async function vPiyasa()').")
sys.exit(1)
