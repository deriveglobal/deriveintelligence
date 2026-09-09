#!/usr/bin/env python3
# YONPORTFOY_ENTEGRASYON_V1 — Yönetici Portföy modülünü canlıya alır (yetki matrisi + nav + enforcement).
# 4 dosya: tenant-admin.js (matris cap "yon-portfoy") + saha_desktop.js (masaüstü nav + iframe VIEW)
#          + saha.js (mobil: müdür Portföyüm içeriği = modül iframe; rep değişmez) + server_container.mjs
#          (SAHA_DEPT_MAP tüm /manager-portfoyum* uçları + _SAHA_NEWK grandfather).
# Idempotent (dosya başına marker guard) + .bak + node --check (.mjs/.cjs) + rollback. TEK build.
# KULLANIM (Fatih): /opt/krb-assessment/ içine koy →
#   cd /opt/krb-assessment && python3 patch_yonportfoy_entegrasyon.py \
#     && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os

def nodecheck(txt):
    for ext in ("mjs","cjs"):
        p="/tmp/_ynchk."+ext; open(p,"w",encoding="utf-8").write(txt)
        if subprocess.run(["node","--check",p],capture_output=True,text=True).returncode==0: return True,""
        last=subprocess.run(["node","--check",p],capture_output=True,text=True).stderr
    return False,last

def patch_file(path, marker, edits):
    if not os.path.exists(path):
        print("HATA: yok:", path); sys.exit(1)
    src=open(path,encoding="utf-8").read()
    if marker in src:
        print("• zaten uygulanmış (%s), atlandı: %s"%(marker,os.path.basename(path))); return
    for old,new in edits:
        c=src.count(old)
        if c!=1:
            print("HATA anchor (%s) count=%d: %r — DUR (canlı beklenenden farklı)."%(os.path.basename(path),c,old[:60])); sys.exit(1)
        src=src.replace(old,new,1)
    ok,err=nodecheck(src)
    if not ok:
        print("HATA node --check (%s):\n%s"%(os.path.basename(path),err)); sys.exit(1)
    shutil.copy(path, path+".bak_ynportfoy"); open(path,"w",encoding="utf-8").write(src)
    print("✓ yamandı:", os.path.basename(path))

EDITS = {
  '/opt/krb-assessment/shells/tenant-admin.js': ('YONPORTFOY_MATRIS_V1', [('["rep-aktivite", "Aktivite"], ["memnuniyet", "Memnuniyet"]]]', '["rep-aktivite", "Aktivite"], ["memnuniyet", "Memnuniyet"], ["yon-portfoy", "Yönetici Portföy"]]]  /* YONPORTFOY_MATRIS_V1 */'), ('"sahasesi-temsilci", "ozet"],', '"sahasesi-temsilci", "ozet", "yon-portfoy"],  /* YONPORTFOY_MATRIS_V1 */')]),
  '/opt/krb-assessment/shells/saha_desktop.js': ('YONPORTFOY_NAV_DK_V1', [('["ceo", "🧠", "CEO Asistan"]]]);', '["ceo", "🧠", "CEO Asistan"], ["yon-portfoy", "🧭", "Yönetici Portföy"]]]);  /* YONPORTFOY_NAV_DK_V1 */'), ('kokpit: "Kokpit", ceo: "CEO Asistan", temsilciler: "Ekip", sistem: "Sistem",', 'kokpit: "Kokpit", ceo: "CEO Asistan", "yon-portfoy": "Yönetici Portföy", temsilciler: "Ekip", sistem: "Sistem",'), ('const VIEWS = {};', 'const VIEWS = {};\nVIEWS["yon-portfoy"] = (m) => {  /* YONPORTFOY_VIEW_DK_V1 */\n  m.style.padding = "0";\n  m.innerHTML = \'<iframe id="ynpf" src="/api/saha/manager-portfoyum/ekran" title="Yönetici Portföy" style="border:0;width:100%;display:block;background:#0b0f17"></iframe>\';\n  const f = m.querySelector("#ynpf");\n  const rz = () => { try { f.style.height = Math.max(360, (window.innerHeight - f.getBoundingClientRect().top)) + "px"; } catch (e) { f.style.height = "100vh"; } };\n  rz(); setTimeout(rz, 60); window.addEventListener("resize", rz);\n};')]),
  '/opt/krb-assessment/shells/saha.js': ('YONPORTFOY_NAV_MOBIL_V1', [('if (room === "portfoyum") { m.style.padding = "0"; vPortfoyum(); return; } /* PORTFOYUM_ROOM_V1 */', 'if (room === "portfoyum") { m.style.padding = "0"; if (["manager","admin"].includes(S.role)) { vYonPortfoyMobil(); } else { vPortfoyum(); } return; } /* PORTFOYUM_ROOM_V1 */ /* YONPORTFOY_NAV_MOBIL_V1 */'), ('async function vPortfoyum(){', 'async function vYonPortfoyMobil(){  /* YONPORTFOY_VIEW_MOBIL_V1 */\n  const _m = main();\n  _m.innerHTML = \'<iframe id="ynpf" src="/api/saha/manager-portfoyum/ekran" title="Yönetici Portföy" style="border:0;width:100%;display:block;background:#0b0f17"></iframe>\';\n  const _f = document.getElementById("ynpf");\n  const _rz = function(){ try{ _f.style.height = Math.max(320, (window.innerHeight - _f.getBoundingClientRect().top)) + "px"; }catch(e){ _f.style.height = "100vh"; } };\n  _rz(); setTimeout(_rz, 60); window.addEventListener("resize", _rz);\n}\nasync function vPortfoyum(){'), ('["portfoyum", "📈", "Portföyüm", "Ciro · tahsilat · segment · canlı", "#7c3aed"], /* PORTFOYUM_ROOM_V1 */', '["portfoyum", "📈", "Portföyüm", _mgmt ? "Ekip · sağlık · kalıcılık" : "Ciro · tahsilat · segment · canlı", "#7c3aed"], /* PORTFOYUM_ROOM_V1 */ /* YONPORTFOY_TILE_MOBIL_V1 */')]),
  '/opt/krb-assessment/server_container.mjs': ('YONPORTFOY_DEPTMAP_V1', [('    "/api/saha/nabiz-ozet": ["memnuniyet"]  /* MEMNUNIYET_GATE_SRV_V1 */\n  };', '    "/api/saha/nabiz-ozet": ["memnuniyet"],  /* MEMNUNIYET_GATE_SRV_V1 */\n    "/api/saha/manager-portfoyum": ["yon-portfoy"],  /* YONPORTFOY_DEPTMAP_V1 */\n    "/api/saha/manager-portfoyum/ekran": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/liste": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/lensler": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/lens-liste": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/beyaz": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/retention": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/retention-liste": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/yazkis": ["yon-portfoy"],\n    "/api/saha/manager-portfoyum/konsantr-liste": ["yon-portfoy"]\n  };'), ('  const _SAHA_NEWK = ["ciro", "risk", "rotam"];', '  const _SAHA_NEWK = ["ciro", "risk", "rotam", "yon-portfoy"];  /* YONPORTFOY_DEPTMAP_V1 */')])
}

for path,(marker,edits) in EDITS.items():
    patch_file(path, marker, edits)
print("\nHepsi tamam. Şimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
