#!/usr/bin/env python3
# LOGOUT_IDLE_FIX_V1 — app.js Face ID kilidi IDLE_MS 3 dk -> 30 dk.
# Saha rep'i telefonu birkac dk cebe koyup donunce her seferinde Face ID istiyordu; Face ID takilirsa
# tek kacis "sifre ile" -> logoutReload -> /api/auth/logout (revoke) -> atiliyor. 30 dk staff idle'iyla ayni.
# Guvenlik korunur (uzun bosta yine kilit). Tek deger. count==1.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/app.js"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
orig = src
new = "    var IDLE_MS = 30 * 60 * 1000; // LOGOUT_IDLE_FIX_V1 — arka planda 30 dk+ ise tekrar kilitle (eski 3 dk saha icin cok agresifti; rep her cep-koymada Face ID + basarisizsa logout oluyordu)"
old = "    var IDLE_MS = 3 * 60 * 1000; // arka planda 3 dk+ ise tekrar kilitle"
if new in src:
    print("SKIP (zaten var)")
else:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c})"
    src = src.replace(old, new)
    bak = PATH + ".bak_logoutidle_" + time.strftime("%Y%m%d_%H%M%S")
    shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    with open(PATH, "w", encoding="utf-8") as f: f.write(src)
    print("OK: IDLE_MS 3dk -> 30dk")
print("LOGOUT_IDLE_FIX_V1 marker:", src.count("LOGOUT_IDLE_FIX_V1"))
