# -*- coding: utf-8 -*-
# IZIN_YENIMODUL_MOB_V1 (saha.js) — mobil Rapor alt-sekmeleri Ciro/Risk/Rotam'ı
#   S.departments ile kapıla. Aynı geriye-uyumlu kural (grandfather).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "IZIN_YENIMODUL_MOB_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) helper'ı rpTabs'tan önce ekle
o1 = '''  const rpTabs = [
    ["ozet",        "📊 Özet"],'''
n1 = '''  const _rd = S.departments || [];  /* IZIN_YENIMODUL_MOB_V1 */
  const _rNEW = ["ciro", "risk", "rotam"], _rHasNew = _rd.some(d => _rNEW.includes(d));
  const _rTabOk = (id) => !_rNEW.includes(id) ? true : (_rHasNew ? _rd.includes(id) : true);
  const rpTabs = [
    ["ozet",        "📊 Özet"],'''
assert s.count(o1) == 1, "helper anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rpTabs dizisini filtrele (kapanış: harita satirindan sonra "  ];")
o2 = '''    ...(isMgr ? [["harita",      "🗺️ Harita"]] : []),
  ];'''
n2 = '''    ...(isMgr ? [["harita",      "🗺️ Harita"]] : []),
  ].filter(([id]) => _rTabOk(id));  /* IZIN_YENIMODUL_MOB_V1 */'''
assert s.count(o2) == 1, "filter anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] IZIN_YENIMODUL_MOB_V1 (saha.js)")
