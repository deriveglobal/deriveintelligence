# -*- coding: utf-8 -*-
# IZIN_ROLDEF_TAD_V1 (tenant-admin.js) — matris kutu durumu:
#   guard (admin/owner/self) → tüm kutular checked+disabled (tam erisim, 👑 tutarli);
#   yeni anahtarlar (ciro/risk/rotam) kaydi olmayan satirda → ROL VARSAYILANINI göster
#   (rep → rotam checked, ciro/risk unchecked; manager → üçü de). Kutu == gerçek görünürlük.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "IZIN_ROLDEF_TAD_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) has satirindan sonra rol-varsayilan degiskenleri
o1 = '      const has = new Set(Array.isArray(perms.departments) ? perms.departments : []);'
n1 = ('      const has = new Set(Array.isArray(perms.departments) ? perms.departments : []);\n'
      '      const _NEWK = ["ciro", "risk", "rotam"], _hasNewRec = _NEWK.some(k => has.has(k));  /* IZIN_ROLDEF_TAD_V1 */\n'
      '      const _rrole = (m && m.module_role) || cfg.roles[0][0], _rdefS = new Set((DEFAULTS[modId] && DEFAULTS[modId][_rrole]) || []);')
assert s.count(o1) == 1, "has anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) cells: guard-all + yeni-anahtar rol-varsayilan fallback
o2 = 'const cells = TOOLS.map(id => { const lock = guard && cfg.lock.includes(id); const chk = (has.has(id) || lock) ? " checked" : ""; return `<td class="ta-cell"><input type="checkbox" class="ta-tool" data-tool="${id}"${chk}${lock ? " disabled" : ""}></td>`; }).join("");'
n2 = 'const cells = TOOLS.map(id => { const lock = guard && cfg.lock.includes(id); const chk = (has.has(id) || lock || guard || (_NEWK.includes(id) && !_hasNewRec && _rdefS.has(id))) ? " checked" : ""; const dis = lock || guard; return `<td class="ta-cell"><input type="checkbox" class="ta-tool" data-tool="${id}"${chk}${dis ? " disabled" : ""}></td>`; }).join("");  /* IZIN_ROLDEF_TAD_V1 */'
assert s.count(o2) == 1, "cells anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] IZIN_ROLDEF_TAD_V1 (tenant-admin.js)")
