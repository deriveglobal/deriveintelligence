# -*- coding: utf-8 -*-
# IZIN_YENIMODUL_DK_V1 (saha_desktop.js) — Rapor alt-sekmeleri Ciro/Risk/Rotam'ı
#   permissions_json.departments ile kapıla. GERİYE UYUMLU:
#   kullanıcıda henüz yeni anahtar kaydı yoksa (grandfather) hepsi görünür;
#   matristen kaydedilince (en az bir yeni anahtar) katı moda geçer.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "IZIN_YENIMODUL_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) helper'ı tabs dizisinden önce ekle
o1 = '''  const tabs = [
    ["ozet", "📊 Özet"],'''
n1 = '''  const _rd = (S.sub && S.sub.permissions && Array.isArray(S.sub.permissions.departments)) ? S.sub.permissions.departments : [];  /* IZIN_YENIMODUL_DK_V1 */
  const _rNEW = ["ciro", "risk", "rotam"], _rHasNew = _rd.some(d => _rNEW.includes(d));
  const _rTabOk = (id) => !_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : true);
  const tabs = [
    ["ozet", "📊 Özet"],'''
assert s.count(o1) == 1, "helper anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) tabs dizisini kapılamayla filtrele
o2 = '''    ["pazar", "🎯 Pazar"]
  ];
  let aktif = "ozet";'''
n2 = '''    ["pazar", "🎯 Pazar"]
  ].filter(([id]) => _rTabOk(id));  /* IZIN_YENIMODUL_DK_V1 */
  let aktif = "ozet";'''
assert s.count(o2) == 1, "filter anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] IZIN_YENIMODUL_DK_V1 (saha_desktop.js)")
