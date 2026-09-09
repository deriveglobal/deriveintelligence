#!/usr/bin/env python3
# VERI_EKRAN_FIX_V2 — /api/bi/veri/ekran yanlış bölümdeydi (saha router, 404-fallback sonrası) + yanlış değişken
# (method/path yerine request.method/url.pathname). Bu fix: yanlış bloğu kaldırır, doğrusunu finans-odasi
# yanına (bi router) doğru değişkenlerle + finansodasi auth deseniyle koyar. Idempotent + .bak + node --check.
# KULLANIM: /opt/krb-assessment/ içine koy →
#   cd /opt/krb-assessment && python3 patch_veri_ekran_fix.py \
#     && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SV='/opt/krb-assessment/server_container.mjs'
MISPLACED_FULL='if (method === "GET" && path === "/api/bi/veri/ekran") {  /* VERI_EKRAN_V1 */\n  if (response.headersSent) return;\n  try {\n    await requireModuleAccess(request, "intelligence");\n    const _h = await readFile("/app/shells/veri_yukle.html", "utf8");\n    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });\n    response.end(_h);\n  } catch (e) {\n    if (!response.headersSent) sendJson(response, 403, { error: "yetki yok / ekran bulunamadi" });\n  }\n  return;\n}\n\nif (method === "GET" && path === "/api/saha/manager-portfoyum/ekran") {'
ANCHOR='if (method === "GET" && path === "/api/saha/manager-portfoyum/ekran") {'
FINANS='  if (request.method === "GET" && url.pathname === "/api/bi/finans-odasi") { /* FINANS_ODASI_SHELL_V2 */'
CORRECT='  if (request.method === "GET" && url.pathname === "/api/bi/veri/ekran") {  /* VERI_EKRAN_V2 */\n    if (response.headersSent) return;\n    try {\n      let _vsess = await requireModuleAccess(request, "intelligence").catch(() => null);\n      if (!_vsess) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) _vsess = _ss; }\n      if (!_vsess) { if (!response.headersSent) sendJson(response, 403, { error: "yetki yok" }); return; }\n      const _h = await readFile("/app/shells/veri_yukle.html", "utf8");\n      response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });\n      response.end(_h);\n    } catch (e) { if (!response.headersSent) sendJson(response, 404, { error: "veri ekrani bulunamadi" }); }\n    return;\n  }\n'
def nc(t):
    for ext in ("mjs","cjs"):
        p="/tmp/_vfx."+ext; open(p,"w",encoding="utf-8").write(t)
        if subprocess.run(["node","--check",p],capture_output=True,text=True).returncode==0: return True,""
        e=subprocess.run(["node","--check",p],capture_output=True,text=True).stderr
    return False,e
src=open(SV,encoding="utf-8").read()
did=False
# A) yanlış bloğu kaldır
if MISPLACED_FULL in src:
    src=src.replace(MISPLACED_FULL, ANCHOR, 1); did=True; print("✓ yanlış yerdeki /api/bi/veri/ekran kaldırıldı.")
else:
    print("• yanlış blok yok (zaten kaldırılmış).")
# B) doğrusunu ekle
if 'url.pathname === "/api/bi/veri/ekran"' in src:
    print("• doğru endpoint zaten var.")
else:
    if FINANS not in src: print("HATA: finans-odasi anchor yok — DUR."); sys.exit(1)
    src=src.replace(FINANS, CORRECT+FINANS, 1); did=True; print("✓ doğru /api/bi/veri/ekran finans-odasi yanına eklendi.")
if not did:
    print("• değişiklik yok."); sys.exit(0)
ok,err=nc(src)
if not ok: print("HATA node --check:\n"+err); sys.exit(1)
shutil.copy(SV,SV+".bak_veriekranfix"); open(SV,"w",encoding="utf-8").write(src)
print("✓ server_container.mjs güncellendi.")
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
