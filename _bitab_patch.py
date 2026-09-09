import sys
F="/opt/krb-assessment/shells/bi.js"
MARK="FINANS_TAB_V1"
s=open(F,encoding="utf-8").read()
if MARK in s:
    print("[bitab] ZATEN YAMALI (marker mevcut) — atlaniyor"); sys.exit(0)

# --- A) NAV BUTTON: CEO Assistant butonundan hemen sonra ---
anchorA=(
'          <button class="vmo-tab" data-dept="brain" style="--c:#e11d48">\n'
'            <span>\U0001F9E0</span> CEO Assistant\n'
'          </button>'
)
nA=s.count(anchorA)
if nA!=1:
    print("[bitab] ANCHOR-A sayisi=%d (tam 1 olmali) — DURDU, dokunulmadi"%nA); sys.exit(2)
buttonA=anchorA+'\n          <button class="vmo-tab" data-dept="finansodasi" style="--c:#059669" title="Finans Odasi" data-mark="'+MARK+'"><span>\U0001F4B0</span> Finans</button>'
s=s.replace(anchorA, buttonA, 1)

# --- B) ROOM BLOCK: `var _METRIK_TANIM = {` oncesine sibling blok ---
anchorB='  var _METRIK_TANIM = {'
nB=s.count(anchorB)
if nB!=1:
    print("[bitab] ANCHOR-B sayisi=%d (tam 1 olmali) — DURDU, dokunulmadi"%nB); sys.exit(3)
block=(
"  // "+MARK+" — ayri 'Finans Odasi' sekmesi (dept=finansodasi) -> iframe /api/bi/finans; Kokpit(kokpit-iki)'ye dokunmaz\n"
"  {\n"
"    const _o = container.querySelector('.vmo-office');\n"
"    if (_o && !document.getElementById('vmo-room-finansodasi')) {\n"
"      const _fo = document.createElement('div');\n"
"      _fo.id = 'vmo-room-finansodasi';\n"
"      _fo.dataset.dept = 'finansodasi';\n"
"      _fo.className = 'vmo-room vmo-room-hidden';\n"
"      _fo.style.cssText = 'background:var(--zemin-0);color:var(--tx-0);overflow-y:auto;padding:0';\n"
"      _fo.innerHTML = '<iframe id=\"finansodasi-frame\" src=\"/api/bi/finans\" style=\"width:100%;height:100%;min-height:82vh;border:0;display:block;background:#0a0e14\" title=\"Finans Odasi\"></iframe>';\n"
"      try { _fo.style.padding = '0'; } catch (e) {}\n"
"      _o.appendChild(_fo);\n"
"    }\n"
"  }\n\n"
)
s=s.replace(anchorB, block+anchorB, 1)
open(F,"w",encoding="utf-8").write(s)
print("[bitab] OK — nav butonu + finansodasi iframe odasi eklendi (Kokpit'e dokunulmadi)")
