# -*- coding: utf-8 -*-
# EKIP_DEPT_GATE_V1 (masaustu) — saha nav'ini departments[] ile ADDITIVE kis
#   (mevcut role/kimlik gate'leri KALIR; departments yalniz DAHA fazla kisitlar).
#   Bos departments -> role fallback (kimse kilitlenmez). ebat/musteri kart araclar'da.
#   Ayrica "Teklif & İskonto" etiketi -> "Teklif" (id degismez: VIEWS.iskonto ayni).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "EKIP_DEPT_GATE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

A1 = '  if (arac.length) g.push(["Araçlar", arac]);\n  return g;\n}'
B1 = '''  if (arac.length) g.push(["Araçlar", arac]);
  /* EKIP_DEPT_GATE_V1 — nav departments[] ile additive kisilir; bos ise role fallback; ebat/musteri araclar */
  const _dept = (S.sub && S.sub.permissions && Array.isArray(S.sub.permissions.departments)) ? S.sub.permissions.departments : [];
  const _dmap = { asistan: "rep-brain", iskonto: "teklif" };
  const _dok = (id) => (id === "ebatkart" || id === "musterikart") ? true : (!_dept.length ? true : _dept.includes(_dmap[id] || id));
  return g.map(gr => [gr[0], gr[1].filter(it => _dok(it[0]))]).filter(gr => gr[1].length);
}'''

A2 = '["iskonto", "💰", "Teklif & İskonto"]'
B2 = '["iskonto", "💰", "Teklif"]'

A3 = 'iskonto: "Teklif & İskonto"'
B3 = 'iskonto: "Teklif"'

for a, b in [(A1, B1), (A2, B2), (A3, B3)]:
    assert s.count(a) == 1, "anchor bulunamadi (%d): %s" % (s.count(a), a[:45])
    s = s.replace(a, b, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] EKIP_DEPT_GATE_V1 (masaustu)")
