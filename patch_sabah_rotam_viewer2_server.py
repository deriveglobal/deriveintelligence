# -*- coding: utf-8 -*-
# SABAH_ROTAM_VIEWER_V2 (server) — VIEWER'ı da panoya yönlendir.
#   requireSahaAccess sahaRole'u yalnız admin/manager/rep üretir; VIEWER → "rep"e düşer (ayırt edilemez).
#   Ham rol session.moduleRole'da ("viewer") korunur → koşula moduleRole==="viewer" ekle.
#   sahaRole global mantığına DOKUNMA (birçok rep-scope kontrolü ona bağlı).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_VIEWER_V2" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SABAH_ROTAM_VIEWER_V1" in s, "HATA: once SABAH_ROTAM_VIEWER_V1 olmali"

o = 'if (session.sahaRole !== "rep") {  /* SABAH_ROTAM_MGR_V1 SABAH_ROTAM_VIEWER_V1 — rep dışı = gözlemci → pano */'
n = 'if (session.sahaRole !== "rep" || session.moduleRole === "viewer") {  /* SABAH_ROTAM_MGR_V1 SABAH_ROTAM_VIEWER_V1 SABAH_ROTAM_VIEWER_V2 — rep dışı + viewer → pano */'
assert s.count(o) == 1, "anchor=%d" % s.count(o)
s = s.replace(o, n, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_VIEWER_V2 (server)")
