# -*- coding: utf-8 -*-
# SABAH_ROTAM_VIEWER_V1 (server) — Rotam'da REP DIŞI herkes (yönetici/admin/VIEWER) ekip panosunu görsün.
#   Eskiden yalnız manager/admin panoyu görüyordu; viewer kişisel rota alıyordu (yanlış — viewer gözlemci).
#   Uygulama geneli konvansiyon: sahaRole !== "rep" = gözlemci ("tüm ekibi görür").
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_VIEWER_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SABAH_ROTAM_MGR_V1" in s, "HATA: once SABAH_ROTAM_MGR_V1 olmali"

o = 'if (session.sahaRole === "manager" || session.sahaRole === "admin") {  /* SABAH_ROTAM_MGR_V1 */'
n = 'if (session.sahaRole !== "rep") {  /* SABAH_ROTAM_MGR_V1 SABAH_ROTAM_VIEWER_V1 — rep dışı = gözlemci → pano */'
assert s.count(o) == 1, "anchor=%d" % s.count(o)
s = s.replace(o, n, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_VIEWER_V1 (server)")
