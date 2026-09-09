#!/usr/bin/env python3
# YONPORTFOY_TOPBAR_V1 — Yönetici Portföy'ü Yönetim (Intelligence/VMO) üst şeridine SEKME olarak ekler.
#   bi.js: "Saha"nın yanına 🧭 Yönetici Portföy sekmesi (saha aboneliği olana) + iframe oda
#          (/api/saha/manager-portfoyum/ekran). Tıklama generic yoldan (Finans Odası deseni).
# Idempotent (marker guard) + .bak + node --check (.mjs/.cjs) + rollback. TEK build.
# KULLANIM: /opt/krb-assessment/ içine koy →
#   cd /opt/krb-assessment && python3 patch_yonportfoy_topbar.py \
#     && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
BI='/opt/krb-assessment/shells/bi.js'
MARK="YONPORTFOY_ODA_V1"
EDITS=[('${(me.subscriptions || []).some(s => s.moduleId === "saha") ? \'<button class="vmo-tab" data-dept="saha" style="--c:#0ea5e9"><span>📍</span> Saha</button>\' : ""}', '${(me.subscriptions || []).some(s => s.moduleId === "saha") ? \'<button class="vmo-tab" data-dept="saha" style="--c:#0ea5e9"><span>📍</span> Saha</button>\' : ""}\n          ${(me.subscriptions || []).some(s => s.moduleId === "saha") ? \'<button class="vmo-tab" data-dept="yonportfoy" style="--c:#3fb9a2"><span>🧭</span> Yönetici Portföy</button>\' : ""}  /* YONPORTFOY_ODA_V1 */'), ('      _o.appendChild(_fo);\n    }\n  }', '      _o.appendChild(_fo);\n    }\n  }\n\n  // YONPORTFOY_ODA_V1 — \'Yönetici Portföy\' üst sekmesi -> iframe /api/saha/manager-portfoyum/ekran\n  {\n    const _o = container.querySelector(\'.vmo-office\');\n    if (_o && (me.subscriptions || []).some(s => s.moduleId === "saha") && !document.getElementById(\'vmo-room-yonportfoy\')) {\n      const _yp = document.createElement(\'div\');\n      _yp.id = \'vmo-room-yonportfoy\';\n      _yp.dataset.dept = \'yonportfoy\';\n      _yp.className = \'vmo-room vmo-room-hidden\';\n      _yp.style.cssText = \'background:var(--zemin-0);color:var(--tx-0);overflow-y:auto;padding:0\';\n      _yp.innerHTML = \'<iframe id="yonportfoy-frame" src="/api/saha/manager-portfoyum/ekran" style="width:100%;height:100%;min-height:82vh;border:0;display:block;background:#0b0f17" title="Yönetici Portföy"></iframe>\';\n      try { _yp.style.padding = \'0\'; } catch (e) {}\n      _o.appendChild(_yp);\n    }\n  }')]
def nodecheck(t):
    for ext in ("mjs","cjs"):
        p="/tmp/_ynbi."+ext; open(p,"w",encoding="utf-8").write(t)
        if subprocess.run(["node","--check",p],capture_output=True,text=True).returncode==0: return True,""
        e=subprocess.run(["node","--check",p],capture_output=True,text=True).stderr
    return False,e
if not os.path.exists(BI): print("HATA yok:",BI); sys.exit(1)
src=open(BI,encoding="utf-8").read()
if MARK in src:
    print("• zaten uygulanmış, atlandı."); sys.exit(0)
for old,new in EDITS:
    c=src.count(old)
    if c!=1: print("HATA anchor count=%d: %r — DUR."%(c,old[:60])); sys.exit(1)
    src=src.replace(old,new,1)
ok,err=nodecheck(src)
if not ok: print("HATA node --check:\n"+err); sys.exit(1)
shutil.copy(BI,BI+".bak_ynportfoytab"); open(BI,"w",encoding="utf-8").write(src)
print("✓ bi.js yamandı (Yönetici Portföy üst sekmesi).")
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
