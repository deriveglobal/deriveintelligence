# -*- coding: utf-8 -*-
# FINANS_GATE_SRV_V1 — Finans odasi sunucu uclarina 'finansodasi' dept zorlamasi.
#   (A) veri ucu /api/bi/finans/ticari-sermaye: requireModuleAccess("intelligence")
#       -> requireBiDept("finansodasi") (owner+modul-admin bypass; manager dept ister). SAHA fallback KORUNUR.
#   (B) shell ucu /api/bi/finans-odasi: ONCEDEN AUTH YOKtu (finans.html son-bilinen sayilari gomulu)
#       -> ayni yetki kapisi eklendi (dept + saha fallback). Sizinti kapatildi.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "FINANS_GATE_SRV_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# --- A) Veri ucu: intelligence modul kapisi -> finansodasi dept kapisi ---
# Anchor BENZERSIZ olsun diye finans pathname'i dahil (bu idiom 7 handler'da var).
OLD_A = ('url.pathname === "/api/bi/finans/ticari-sermaye") {\n'
         '    if (response.headersSent) return;\n'
         '    try {\n'
         '      let session = await requireModuleAccess(request, "intelligence").catch(() => null);')
NEW_A = ('url.pathname === "/api/bi/finans/ticari-sermaye") {\n'
         '    if (response.headersSent) return;\n'
         '    try {\n'
         '      let session = await requireBiDept(request, "finansodasi").catch(() => null);  /* FINANS_GATE_SRV_V1 */')
assert s.count(OLD_A) == 1, "A anchor (veri ucu) bulunamadi (%d)" % s.count(OLD_A)
s = s.replace(OLD_A, NEW_A, 1)

# --- B) Shell ucu: auth ekle (readFile oncesi) ---
OLD_B = ('  if (request.method === "GET" && url.pathname === "/api/bi/finans-odasi") { /* FINANS_ODASI_SHELL_V2 */\n'
         '    if (response.headersSent) return;\n'
         '    try {\n'
         '      const _h = await readFile("/app/shells/finans.html", "utf8");')
NEW_B = ('  if (request.method === "GET" && url.pathname === "/api/bi/finans-odasi") { /* FINANS_ODASI_SHELL_V2 */\n'
         '    if (response.headersSent) return;\n'
         '    try {\n'
         '      let _fsess = await requireBiDept(request, "finansodasi").catch(() => null);  /* FINANS_GATE_SRV_V1 */\n'
         '      if (!_fsess) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) _fsess = _ss; }\n'
         '      if (!_fsess) { if (!response.headersSent) sendJson(response, 403, { error: "yetki yok" }); return; }\n'
         '      const _h = await readFile("/app/shells/finans.html", "utf8");')
assert s.count(OLD_B) == 1, "B anchor (shell ucu) bulunamadi (%d)" % s.count(OLD_B)
s = s.replace(OLD_B, NEW_B, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] FINANS_GATE_SRV_V1 (server: veri + shell ucu dept-gated)")
