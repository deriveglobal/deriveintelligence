# -*- coding: utf-8 -*-
# IZIN_SAHADEPT_V1 (server) — Saha alt-sekme SUNUCU yetkilendirmesi (requireBiDept muadili).
#   Ciro/Risk/Rotam endpoint'leri artik departments[] denetler → yetkisizde 403.
#   Rol-varsayilani/grandfather mantigi client _rTabOk ile BIRE BIR ayni (UI ve sunucu tutarli).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "IZIN_SAHADEPT_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 0) taban dogrulamasi — beklenen canli sunucu
assert "async function requireSahaAccess(req, allowedRoles = null) {" in s, "requireSahaAccess yok — taban beklenmedik"

# 1) requireSahaDept fonksiyonunu requireSahaAccess'in hemen ardina ekle
o1 = "    return { ...session, sahaRole };\n  }\n"
n1 = ("    return { ...session, sahaRole };\n  }\n\n"
      "  async function requireSahaDept(request, dept) {  /* IZIN_SAHADEPT_V1 — Saha alt-sekme sunucu yetkilendirmesi */\n"
      "    const session = await requireSahaAccess(request);\n"
      "    if (session.sahaRole === \"admin\") return session;                 // admin = tam erisim (bypass)\n"
      "    const depts = Array.isArray(session.permissions && session.permissions.departments) ? session.permissions.departments : [];\n"
      "    if (depts.includes(dept)) return session;                         // acik yetki\n"
      "    const NEWK = [\"ciro\", \"risk\", \"rotam\"];\n"
      "    const hasNewRec = NEWK.some(k => depts.includes(k));\n"
      "    if (!hasNewRec) {                                                  // kayit yok -> ROL VARSAYILANI (client _rTabOk ile ayni)\n"
      "      if (session.sahaRole === \"manager\") return session;             // manager = hepsi\n"
      "      if (session.sahaRole === \"rep\" && dept === \"rotam\") return session; // rep = yalniz rotam\n"
      "    }\n"
      "    throw Object.assign(new Error(\"Bu sekme için yetkiniz yok: \" + dept), { statusCode: 403 });\n"
      "  }\n")
assert s.count(o1) == 1, "requireSahaAccess kapanis anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) uc endpoint: requireSahaAccess -> requireSahaDept (path satiriyla benzersizlestir)
def swap(path_marker, dept):
    global s
    o = ('    if (method === "GET" && path === "/api/saha/rapor/%s\n'
         '      const session = await requireSahaAccess(request);') % path_marker
    n = ('    if (method === "GET" && path === "/api/saha/rapor/%s\n'
         '      const session = await requireSahaDept(request, "%s");  /* IZIN_SAHADEPT_V1 */') % (path_marker, dept)
    assert s.count(o) == 1, "%s anchor=%d" % (path_marker, s.count(o))
    s = s.replace(o, n, 1)

swap('ziyaret-ciro") {  /* ZIYARET_CIRO_V1 */', "ciro")
swap('risk-saha") {  /* RISK_SAHA_V1 */',       "risk")
swap('sabah-rotam") {  /* SABAH_ROTAM_V1 */',   "rotam")

open(F, "w", encoding="utf-8").write(s)
print("[done] IZIN_SAHADEPT_V1 (server) — requireSahaDept + 3 endpoint denetimi")
