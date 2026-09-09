# -*- coding: utf-8 -*-
# EKIP_DEPT_GATE_V1 (mobil) — saha nav'ini departments[] ile ADDITIVE kis.
#   S'e departments stash (layout ondan okur). tabs + rooms gate. Bos -> role fallback.
#   Mobil id 'iskonto' -> dept 'teklif' map (mobil nav id degismez). rep-brain zaten kanonik.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "EKIP_DEPT_GATE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) S'e departments ekle (init'te, layout cagrilmadan once)
A1 = '    gosterilmisOnaylandi: new Set() // track quote IDs already toasted to rep\n  };'
B1 = '    gosterilmisOnaylandi: new Set(), // track quote IDs already toasted to rep\n    departments: (sub && sub.permissions && Array.isArray(sub.permissions.departments)) ? sub.permissions.departments : []  /* EKIP_DEPT_GATE_V1 */\n  };'

# 2) tabs'i departments ile kis; coreTabs/moreTabs filtreli listeden
A2 = '''  const CORE = ["bugun","ziyaretler","iskonto","rep-brain"];
  S.coreIds = CORE;
  const coreTabs = tabs.filter(t => CORE.includes(t[0]));
  S.moreTabs = tabs.filter(t => !CORE.includes(t[0]));'''
B2 = '''  /* EKIP_DEPT_GATE_V1 — departments[] ile additive kis; bos ise role fallback */
  const _dmap = { iskonto: "teklif" };
  const _dok = (id) => (!S.departments || !S.departments.length) ? true : S.departments.includes(_dmap[id] || id);
  const tabsG = tabs.filter(t => _dok(t[0]));
  const CORE = ["bugun","ziyaretler","iskonto","rep-brain"];
  S.coreIds = CORE;
  const coreTabs = tabsG.filter(t => CORE.includes(t[0]));
  S.moreTabs = tabsG.filter(t => !CORE.includes(t[0]));'''

# 3) ROOMS'u da gate (saha her zaman; rakip/kokpit/ceo departments'a bagli)
A3 = '  const ROOMS = [["saha","🗂","Saha"],["rakip","🏷","Rakip"], ...(_mgmt ? [["kokpit","📊","Kokpit"],["ceo","🧠","CEO"]] : [])];'
B3 = '  const ROOMS = [["saha","🗂","Saha"],["rakip","🏷","Rakip"], ...(_mgmt ? [["kokpit","📊","Kokpit"],["ceo","🧠","CEO"]] : [])].filter(r => r[0] === "saha" ? true : _dok(r[0]));  /* EKIP_DEPT_GATE_V1 */'

for a, b in [(A1, B1), (A2, B2), (A3, B3)]:
    assert s.count(a) == 1, "anchor bulunamadi (%d): %s" % (s.count(a), a[:45])
    s = s.replace(a, b, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] EKIP_DEPT_GATE_V1 (mobil)")
